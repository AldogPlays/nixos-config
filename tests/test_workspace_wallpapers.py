"""Policy/IPC tests, without changing the running desktop or personal images."""

import importlib.util
import json
import os
from pathlib import Path
import random
import tempfile
from concurrent.futures import ThreadPoolExecutor
import unittest
from unittest import mock

from PIL import Image


spec = importlib.util.spec_from_file_location(
    "wallpapers", Path(__file__).parents[1] / "dotfiles/hypr/workspace-wallpapers.py"
)
wallpapers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpapers)


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.images = self.root / "images"
        self.images.mkdir()
        for number in range(15):
            Image.new("RGB", (120, 80), (number, 50, 100)).save(
                self.images / f"image {number}.png"
            )
        self.state = self.root / "state.json"
        self.monitors = [{"name": "eDP-1", "activeWorkspace": {"id": 1}}]
        self.sizes = {"eDP-1": (80, 50)}
        self.calls = []

    def fake_command(self, *args):
        self.calls.append(args)
        if args == ("-j", "monitors"):
            return json.dumps(
                [
                    {
                        **monitor,
                        "width": self.sizes.get(monitor["name"], (100, 60))[0],
                        "height": self.sizes.get(monitor["name"], (100, 60))[1],
                        "scale": 1,
                        "transform": monitor.get("transform", 0),
                    }
                    for monitor in self.monitors
                ]
            )
        if args == ("-j", "workspaces"):
            return json.dumps([{"id": 1}])
        self.fail(f"Unexpected command: {args}")

    def reconcile(self, now=9000):
        return wallpapers.reconcile(
            self.images, self.state, 900, self.fake_command, now
        )

    def test_switch_and_reload_remember_empty_workspaces(self):
        original = self.reconcile()
        self.assertEqual(len(set(original["assignments"].values())), 10)
        self.monitors[0]["activeWorkspace"]["id"] = 2
        self.reconcile(9100)
        self.assertEqual(json.loads(self.state.read_text()), original)
        self.monitors[0]["activeWorkspace"]["id"] = 1
        self.assertEqual(self.reconcile(9899), original)
        modified = self.state.stat().st_mtime_ns
        self.reconcile(9899)
        self.assertEqual(self.state.stat().st_mtime_ns, modified)

    def test_rotation_changes_hidden_and_visible_assignments(self):
        original = self.reconcile()
        updated = self.reconcile(9900)
        self.assertEqual(len(set(updated["assignments"].values())), 10)
        for key, image in original["assignments"].items():
            self.assertNotEqual(image, updated["assignments"][key])
        self.assertEqual(json.loads(self.state.read_text()), updated)

    def test_helper_restart_preserves_the_manifest(self):
        original = self.reconcile()
        self.assertEqual(self.reconcile(9100), original)
        self.assertEqual(json.loads(self.state.read_text()), original)

    def test_atomic_manifest_tracks_rotation_and_prepared_files(self):
        original = self.reconcile()
        self.assertEqual(json.loads(self.state.read_text()), original)
        updated = self.reconcile(9900)
        self.assertEqual(updated["epoch"], 11)
        self.assertEqual(json.loads(self.state.read_text()), updated)
        self.assertFalse(self.state.with_suffix(".tmp").exists())
        self.assertTrue(
            all(Path(path).is_file() for path in updated["prepared"]["eDP-1"].values())
        )
        self.assertTrue(
            all(
                call in (("-j", "monitors"), ("-j", "workspaces"))
                for call in self.calls
            )
        )

    def test_multiple_monitors_and_additional_workspace(self):
        self.monitors.append({"name": "DP-1", "activeWorkspace": {"id": 42}})
        state = self.reconcile()
        self.assertTrue(Path(state["prepared"]["DP-1"]["42"]).is_file())
        self.assertNotEqual(
            state["prepared"]["DP-1"]["42"], state["prepared"]["eDP-1"]["1"]
        )

    def test_deleted_image_is_replaced_without_resetting_other_assignments(self):
        original = self.reconcile()
        Path(original["assignments"]["1"]).unlink()
        updated = self.reconcile(9100)
        self.assertNotEqual(original["assignments"]["1"], updated["assignments"]["1"])
        self.assertEqual(original["assignments"]["2"], updated["assignments"]["2"])

    def test_empty_folder_and_corrupt_cache(self):
        self.state.write_text("not json")
        for image in self.images.iterdir():
            image.unlink()
        self.assertEqual(self.reconcile()["assignments"], {})
        self.assertEqual(json.loads(self.state.read_text())["prepared"], {"eDP-1": {}})

    def test_empty_collection_publishes_empty_assignments(self):
        self.reconcile()
        for image in self.images.iterdir():
            image.unlink()
        self.assertEqual(self.reconcile(9100)["assignments"], {})
        self.assertEqual(json.loads(self.state.read_text())["prepared"], {"eDP-1": {}})

    def test_prepared_images_are_sized_cached_and_bounded(self):
        original = self.reconcile()
        render = Path(original["prepared"]["eDP-1"]["1"])
        with Image.open(render) as image:
            self.assertEqual(image.size, (80, 50))
            self.assertEqual(image.format, "BMP")
        modified = render.stat().st_mtime_ns
        self.reconcile(9100)
        self.assertEqual(render.stat().st_mtime_ns, modified)
        self.sizes["eDP-1"] = (100, 60)
        updated = self.reconcile(9200)
        self.assertEqual(original["assignments"], updated["assignments"])
        replacement = Path(updated["prepared"]["eDP-1"]["1"])
        with Image.open(replacement) as image:
            self.assertEqual(image.size, (100, 60))
        cache = self.root / "workspace-wallpaper-images"
        self.assertEqual(len(list(cache.glob("*.bmp"))), 20)
        self.assertTrue(
            render.exists()
        )  # previous set is retained for in-flight requests
        self.sizes["eDP-1"] = (110, 70)
        self.reconcile(9300)
        self.assertEqual(len(list(cache.glob("*.bmp"))), 20)
        self.assertFalse(render.exists())  # older-than-previous render is pruned

    def test_corrupt_image_is_replaced_without_breaking_rotation(self):
        original = self.reconcile()
        Path(original["assignments"]["1"]).write_bytes(b"not an image")
        updated = self.reconcile(9100)
        self.assertNotEqual(original["assignments"]["1"], updated["assignments"]["1"])
        self.assertEqual(original["assignments"]["2"], updated["assignments"]["2"])

    def test_repeated_assignment_is_prepared_once_per_update(self):
        for image in list(self.images.iterdir())[1:]:
            image.unlink()
        with mock.patch.object(
            wallpapers, "prepare_image", wraps=wallpapers.prepare_image
        ) as prepare:
            state = self.reconcile()
        self.assertEqual(prepare.call_count, 1)
        self.assertEqual(len(set(state["prepared"]["eDP-1"].values())), 1)

    def test_equal_sized_outputs_share_preparation(self):
        self.monitors.append({"name": "DP-1", "activeWorkspace": {"id": 2}})
        self.sizes["DP-1"] = self.sizes["eDP-1"]
        with mock.patch.object(
            wallpapers, "prepare_image", wraps=wallpapers.prepare_image
        ) as prepare:
            state = self.reconcile()
        self.assertEqual(prepare.call_count, 10)
        self.assertEqual(state["prepared"]["DP-1"], state["prepared"]["eDP-1"])

    def test_failed_source_retry_keeps_successful_preparations(self):
        prepare = wallpapers.prepare_image
        attempts = {}
        rejected = None

        def fail_one_source(source, size, directory):
            nonlocal rejected
            identity = (source, size)
            attempts[identity] = attempts.get(identity, 0) + 1
            if rejected is None:
                rejected = source
            if source == rejected:
                raise OSError("Unusable source")
            return prepare(source, size, directory)

        with mock.patch.object(
            wallpapers, "prepare_image", side_effect=fail_one_source
        ):
            state = self.reconcile()
        self.assertNotIn(rejected, state["assignments"].values())
        self.assertEqual(len(attempts), 11)
        self.assertTrue(all(count == 1 for count in attempts.values()))

    def test_source_metadata_is_rechecked_on_next_update(self):
        original = self.reconcile()
        source = original["assignments"]["1"]
        Image.new("RGB", (121, 81), (200, 100, 20)).save(source)
        updated = self.reconcile(9100)
        self.assertEqual(original["assignments"], updated["assignments"])
        self.assertNotEqual(
            original["prepared"]["eDP-1"]["1"], updated["prepared"]["eDP-1"]["1"]
        )

    def test_preparation_never_applies_a_stale_workspace_snapshot(self):
        prepare = wallpapers.prepare_image

        def switch_and_prepare(*args):
            self.monitors[0]["activeWorkspace"]["id"] = 2
            return prepare(*args)

        with mock.patch.object(
            wallpapers, "prepare_image", side_effect=switch_and_prepare
        ):
            updated = self.reconcile()
        self.assertTrue(Path(updated["prepared"]["eDP-1"]["2"]).is_file())
        self.assertEqual(self.calls, [("-j", "monitors"), ("-j", "workspaces")])

    def test_old_manifest_remains_published_until_preparation_finishes(self):
        original = self.reconcile()
        prepare = wallpapers.prepare_image

        def inspect_and_prepare(*args):
            self.assertEqual(json.loads(self.state.read_text()), original)
            return prepare(*args)

        with mock.patch.object(
            wallpapers, "prepare_image", side_effect=inspect_and_prepare
        ):
            updated = self.reconcile(9900)
        self.assertEqual(json.loads(self.state.read_text()), updated)

    def test_recursive_discovery_and_safe_names(self):
        folder = self.images / "nested"
        folder.mkdir()
        (folder / "a 'quoted' image.JPG").touch()
        (folder / "comma,name.png").touch()
        (folder / "notes.txt").touch()
        found = wallpapers.discover(self.images)
        self.assertIn(str(folder / "a 'quoted' image.JPG"), found)
        self.assertIn(str(folder / "comma,name.png"), found)
        self.assertFalse(any(image.endswith(".txt") for image in found))

    def test_pinned_decoder_formats(self):
        (self.images / "unsupported.avif").touch()
        (self.images / "unsupported.jxl").touch()
        self.assertFalse(
            any(
                Path(image).suffix in {".avif", ".jxl"}
                for image in wallpapers.discover(self.images)
            )
        )

    def test_small_collections_and_unique_derangements(self):
        for count in (1, 2, 10, 15):
            images = [str(number) for number in range(count)]
            keys = [str(number) for number in range(10)]
            previous = {}
            for _ in range(100):
                result = wallpapers.assign(keys, images, previous)
                if count >= len(keys):
                    self.assertEqual(len(set(result.values())), len(keys))
                if count > 1:
                    self.assertTrue(
                        all(result[key] != previous.get(key) for key in keys)
                    )
                previous = result


class PreparedCacheTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "original.jpg"
        image = Image.new("RGB", (127, 83))
        for x in range(image.width):
            for y in range(image.height):
                image.putpixel((x, y), (x, y, (x + y) % 256))
        exif = image.getexif()
        exif[274] = 6  # Rotation must remain identical on cached and cold paths.
        image.save(self.source, exif=exif)
        self.disk = self.root / "persistent"
        self.cache = wallpapers.PreparedCache(self.disk)
        self.size = (80, 50)

    def prepare(self, session, size=None, cache=True):
        runtime = self.root / session
        runtime.mkdir(exist_ok=True)
        return Path(
            wallpapers.prepare_image(
                self.source, size or self.size, runtime, self.cache if cache else None
            )
        )

    def test_new_session_reuses_exact_pixels_without_decoding_original(self):
        baseline = self.prepare("reference", cache=False).read_bytes()
        first = self.prepare("session-one")
        self.assertEqual(first.read_bytes(), baseline)
        with mock.patch.object(Image, "open", side_effect=AssertionError("decoded")):
            second = self.prepare("session-two")
        self.assertEqual(second.read_bytes(), baseline)
        cached = self.disk / first.name
        self.assertNotEqual(first.stat().st_ino, cached.stat().st_ino)
        self.assertNotEqual(second.stat().st_ino, cached.stat().st_ino)
        first.unlink()
        self.assertTrue(cached.exists())
        self.assertTrue(second.exists())

    def test_existing_runtime_image_seeds_persistent_cache(self):
        first = self.prepare("session", cache=False)
        self.assertFalse(self.disk.exists())
        with mock.patch.object(Image, "open", side_effect=AssertionError("decoded")):
            self.prepare("session")
        self.assertEqual((self.disk / first.name).read_bytes(), first.read_bytes())

    def test_reconciliation_publishes_only_session_paths_on_cache_hits(self):
        images = self.root / "images"
        images.mkdir()
        (images / self.source.name).write_bytes(self.source.read_bytes())

        def run(*args):
            return json.dumps(
                [
                    {
                        "name": "eDP-1",
                        "width": 80,
                        "height": 50,
                        "activeWorkspace": {"id": 1},
                    }
                ]
                if args == ("-j", "monitors")
                else [{"id": 1}]
            )

        states = []
        for session in ("one", "two"):
            directory = self.root / session
            directory.mkdir()
            with mock.patch.object(
                Image,
                "open",
                wraps=Image.open if session == "one" else None,
                side_effect=None if session == "one" else AssertionError("decoded"),
            ):
                states.append(
                    wallpapers.reconcile(
                        images, directory / "state.json", 900, run, 9000, self.cache
                    )
                )
            for path in states[-1]["prepared"]["eDP-1"].values():
                self.assertEqual(Path(path).parent.parent, directory)
                self.assertTrue(Path(path).is_file())
        self.assertEqual(states[0]["assignments"], states[1]["assignments"])

    def test_source_changes_and_output_dimensions_invalidate_cache(self):
        first = self.prepare("one")
        metadata = self.source.stat()
        os.utime(self.source, ns=(metadata.st_atime_ns, metadata.st_mtime_ns + 1))
        second = self.prepare("two")
        third = self.prepare("three", size=(50, 80))
        self.assertEqual(len({first.name, second.name, third.name}), 3)
        with Image.open(third) as image:
            self.assertEqual(image.size, (50, 80))

    def test_corrupt_cached_bmp_is_rebuilt(self):
        first = self.prepare("one")
        cached = self.disk / first.name
        for corrupt in (b"broken", first.read_bytes()[:-1]):
            with self.subTest(length=len(corrupt)):
                cached.write_bytes(corrupt)
                first.unlink(missing_ok=True)
                self.prepare("one")
                self.assertEqual(cached.read_bytes(), first.read_bytes())

    def test_wrong_dimensions_with_same_payload_length_are_rebuilt(self):
        first = self.prepare("one")
        baseline = first.read_bytes()
        # Both row strides are 240 bytes, so length alone cannot catch this.
        Image.new("RGB", (79, 50), "red").save(self.disk / first.name)
        first.unlink()
        self.assertEqual(self.prepare("one").read_bytes(), baseline)

    def test_unavailable_cache_and_failed_writes_keep_good_source(self):
        self.disk.touch()  # A regular file cannot be used as a cache directory.
        first = self.prepare("one")
        self.assertTrue(first.is_file())
        self.disk.unlink()
        with mock.patch.object(wallpapers, "copy_atomic", side_effect=OSError("full")):
            second = self.prepare("two")
        self.assertEqual(second.read_bytes(), first.read_bytes())

    def test_interrupted_copy_is_not_published_and_temporary_is_removed(self):
        first = self.prepare("one")
        baseline = first.read_bytes()

        def fail_copy(source, destination):
            destination.write(source.read(20))
            raise OSError("interrupted copy")

        with mock.patch.object(wallpapers.shutil, "copyfileobj", side_effect=fail_copy):
            second = self.prepare("two")
        self.assertEqual(second.read_bytes(), baseline)
        self.assertEqual((self.disk / first.name).read_bytes(), baseline)
        self.assertEqual(list(second.parent.iterdir()), [second])

    def test_budget_evicts_least_recently_used_without_touching_runtime(self):
        first = self.prepare("one")
        size = first.stat().st_size
        self.cache.limit = size * 2
        second = self.prepare("two", size=(79, 50))
        older = self.disk / first.name
        os.utime(older, ns=(1, 1))
        # A cache hit refreshes recency, even when a different session uses it.
        self.prepare("three")
        os.utime(self.disk / second.name, ns=(2, 2))
        third = self.prepare("four", size=(78, 50))
        self.assertTrue(older.exists())
        self.assertFalse((self.disk / second.name).exists())
        self.assertTrue((self.disk / third.name).exists())
        self.assertTrue(first.exists() and second.exists() and third.exists())
        self.assertLessEqual(
            sum(path.stat().st_size for path in self.disk.glob("*.bmp")),
            self.cache.limit,
        )

    def test_zero_budget_and_oversized_entries_use_runtime_only(self):
        self.cache.limit = 0
        self.prepare("one")
        self.assertEqual(list(self.disk.glob("*.bmp")), [])
        self.cache.limit = 1
        self.prepare("two")
        self.assertEqual(list(self.disk.glob("*.bmp")), [])

    def test_cleanup_preserves_symlinks_and_unrelated_files(self):
        first = self.prepare("one")
        cached = self.disk / first.name
        cached.unlink()
        cached.symlink_to(self.source)
        unrelated = self.disk / "personal.bmp"
        unrelated.write_bytes(b"keep")
        directory = self.disk / ("a" * 64 + ".bmp")
        directory.mkdir()
        self.cache.limit = 0
        self.prepare("two")
        self.assertTrue(cached.is_symlink())
        self.assertEqual(unrelated.read_bytes(), b"keep")
        self.assertTrue(directory.is_dir())
        self.assertTrue(self.source.is_file())

    def test_parallel_sessions_publish_complete_independent_files(self):
        with ThreadPoolExecutor(max_workers=4) as executor:
            paths = list(executor.map(self.prepare, ["one", "two", "three", "four"]))
        self.assertEqual(len({path.read_bytes() for path in paths}), 1)
        self.assertEqual(len(list(self.disk.glob("*.bmp"))), 1)
        self.assertEqual(
            {path.name for path in self.disk.iterdir()}, {".lock", paths[0].name}
        )


if __name__ == "__main__":
    random.seed(42)
    unittest.main()
