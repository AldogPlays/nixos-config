"""Policy/IPC tests, without changing the running desktop or personal images."""

import importlib.util
import json
from pathlib import Path
import random
import tempfile
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
        self.active = {}
        self.changes = []

    def fake_command(self, *args):
        if args == ("-j", "monitors"):
            return json.dumps(self.monitors)
        if args == ("-j", "workspaces"):
            return json.dumps([{"id": 1}])
        if args == ("awww", "query", "--json"):
            return json.dumps(
                {
                    "": [
                        {
                            "name": monitor["name"],
                            "width": self.sizes.get(monitor["name"], (100, 60))[0],
                            "height": self.sizes.get(monitor["name"], (100, 60))[1],
                            "scale": 1,
                            "displaying": {"image": self.active.get(monitor["name"])},
                        }
                        for monitor in self.monitors
                    ]
                }
            )
        self.assertEqual(
            args[:7],
            ("awww", "img", "--transition-type", "none", "--resize", "no", "--outputs"),
        )
        name, separator, image = args[7:]
        self.assertEqual(separator, "--")
        self.assertTrue(Path(image).is_file())
        self.active[name] = image
        self.changes.append((name, image))
        return "ok"

    def reconcile(self, now=9000):
        return wallpapers.reconcile(
            self.images, self.state, 900, self.fake_command, now
        )

    def test_switch_and_reload_remember_empty_workspaces(self):
        original = self.reconcile()
        self.assertEqual(len(set(original["assignments"].values())), 10)
        self.monitors[0]["activeWorkspace"]["id"] = 2
        self.reconcile(9100)
        self.assertEqual(self.active["eDP-1"], original["prepared"]["eDP-1"]["2"])
        self.monitors[0]["activeWorkspace"]["id"] = 1
        self.assertEqual(self.reconcile(9899), original)
        self.assertEqual(self.active["eDP-1"], original["prepared"]["eDP-1"]["1"])
        changes = len(self.changes)
        self.reconcile(9899)
        self.assertEqual(len(self.changes), changes)

    def test_rotation_changes_hidden_and_visible_assignments(self):
        original = self.reconcile()
        updated = self.reconcile(9900)
        self.assertEqual(len(set(updated["assignments"].values())), 10)
        for key, image in original["assignments"].items():
            self.assertNotEqual(image, updated["assignments"][key])
        self.assertEqual(self.active["eDP-1"], updated["prepared"]["eDP-1"]["1"])

    def test_backend_restart_restores_without_reshuffle(self):
        original = self.reconcile()
        self.active.clear()
        self.assertEqual(self.reconcile(9100), original)
        self.assertEqual(self.active["eDP-1"], original["prepared"]["eDP-1"]["1"])

    def test_fast_path_cache_is_plain_data_and_tracks_rotation(self):
        original = self.reconcile()
        cache = self.state.with_suffix("") / "eDP-1".encode().hex()
        for key, image in original["assignments"].items():
            render = original["prepared"]["eDP-1"][key]
            self.assertEqual((cache / key).read_text(), f"10\n{image}\n{render}")
        updated = self.reconcile(9900)
        for key, image in updated["assignments"].items():
            render = updated["prepared"]["eDP-1"][key]
            self.assertEqual((cache / key).read_text(), f"11\n{image}\n{render}")

    def test_multiple_monitors_and_additional_workspace(self):
        self.monitors.append({"name": "DP-1", "activeWorkspace": {"id": 42}})
        state = self.reconcile()
        self.assertEqual(self.active["DP-1"], state["prepared"]["DP-1"]["42"])
        self.assertNotEqual(self.active["DP-1"], self.active["eDP-1"])

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
        self.assertFalse(self.changes)

    def test_empty_collection_invalidates_existing_fast_path_cache(self):
        self.reconcile()
        for image in self.images.iterdir():
            image.unlink()
        self.assertEqual(self.reconcile(9100)["assignments"], {})
        for entry in (self.state.with_suffix("") / "eDP-1".encode().hex()).iterdir():
            self.assertEqual(entry.read_text(), "10\n\n")

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

    def test_switch_during_preparation_applies_latest_workspace(self):
        prepare = wallpapers.prepare_image

        def switch_and_prepare(*args):
            self.monitors[0]["activeWorkspace"]["id"] = 2
            return prepare(*args)

        with mock.patch.object(
            wallpapers, "prepare_image", side_effect=switch_and_prepare
        ):
            updated = self.reconcile()
        self.assertEqual(self.active["eDP-1"], updated["prepared"]["eDP-1"]["2"])

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


if __name__ == "__main__":
    random.seed(42)
    unittest.main()
