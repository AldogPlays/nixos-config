"""Run only a disposable nested compositor; never load plugins into the host."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
from PIL import Image

plugin = sys.argv[1]
grim = sys.argv[2]
parent_socket = str(Path(os.environ["XDG_RUNTIME_DIR"], os.environ["WAYLAND_DISPLAY"]))
with tempfile.TemporaryDirectory(prefix="", dir="/tmp") as directory:
    root = Path(directory)
    env = dict(
        os.environ,
        XDG_RUNTIME_DIR=directory,
        XDG_CACHE_HOME=directory,
        XDG_CONFIG_HOME=directory,
        XDG_STATE_HOME=directory,
        DBUS_SESSION_BUS_ADDRESS="unix:path=" + directory + "/no-bus",
        WAYLAND_DISPLAY=parent_socket,
        AQ_DRM_DEVICES="/dev/null",
        HYPRLAND_NO_RT="1",
        HYPRLAND_NO_SD_NOTIFY="1",
    )
    env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
    config = root / "hyprland.lua"
    config.write_text(
        """
hl.monitor({ output = "", mode = "640x400@60", position = "auto", scale = 1 })
hl.config({
    misc = {
        disable_hyprland_logo = true, disable_splash_rendering = true,
        background_color = "rgb(eff1f5)",
    },
    ecosystem = { no_update_news = true, no_donation_nag = true },
    animations = { enabled = true },
    xwayland = { enabled = false },
})
hl.plugin.load("@PLUGIN_PATH@")
hl.curve("smooth", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth" })
""".replace("@PLUGIN_PATH@", plugin)
    )
    log = (root / "test.log").open("w+")
    child = subprocess.Popen(
        ["/run/current-system/sw/bin/Hyprland", "--config", str(config)],
        env=env,
        stdout=log,
        stderr=log,
    )
    try:
        session = None
        for _ in range(100):
            if child.poll() is not None:
                raise RuntimeError("Nested compositor exited before readiness")
            choices = list((root / "hypr").glob("*/.socket.sock"))
            if choices:
                session = choices[0].parent
                break
            time.sleep(0.1)
        assert session, "No nested control socket"
        env["HYPRLAND_INSTANCE_SIGNATURE"] = session.name
        env["WAYLAND_DISPLAY"] = str(
            next(p for p in root.glob("wayland-*") if p.is_socket())
        )

        def ctl(*args):
            return subprocess.check_output(
                ["hyprctl", *args],
                env=env,
                text=True,
                stderr=subprocess.PIPE,
                timeout=5,
            )

        monitors = []
        for _ in range(150):
            try:
                monitors = json.loads(ctl("-j", "monitors"))
                if monitors:
                    break
            except (subprocess.SubprocessError, ValueError):
                pass
            time.sleep(0.1)
        assert monitors, "No nested monitor"
        assert not ctl("configerrors").strip(), ctl("configerrors")
        assert any(
            p["name"] == "hyprmosaic" for p in json.loads(ctl("-j", "plugin", "list"))
        )
        assert ctl("eval", "hl.dispatch(hl.dsp.focus({workspace=1}))").strip() == "ok"
        time.sleep(0.6)
        print("PASS: plugin loads in isolated compositor with matching ABI")
        cache = session / "workspace-wallpaper-images"
        cache.mkdir()
        prepared = {}
        for mon in monitors:
            images = prepared[mon["name"]] = {}
            for number in (1, 2, 3):
                image = cache / (
                    hashlib.sha256(f"test-{number}".encode()).hexdigest() + ".bmp"
                )
                Image.new(
                    "RGB",
                    (640, 400),
                    {1: (91, 83, 67), 2: (40, 80, 160), 3: (120, 50, 90)}[number],
                ).save(image)
                images[str(number)] = str(image)

        def publish(value):
            temporary = session / "test.tmp"
            temporary.write_text(json.dumps({"prepared": value}))
            temporary.replace(session / "workspace-wallpapers.json")

        def wait_loaded(previous):
            for _ in range(100):
                status = json.loads(ctl("hyprmosaic:status"))
                if status["manifest_loads"] > previous:
                    return status
                time.sleep(0.03)
            raise AssertionError(("Manifest did not load", status))

        def update(value):
            previous = json.loads(ctl("hyprmosaic:status"))["manifest_loads"]
            publish(value)
            return wait_loaded(previous)

        def wait_removed(path):
            for _ in range(100):
                if not path.exists():
                    return
                time.sleep(0.03)
            raise AssertionError(("Stale generated image retained", str(path)))

        publish(prepared)
        for _ in range(50):
            status = json.loads(ctl("hyprmosaic:status"))
            if status["resident_images"] == 3 * len(monitors):
                break
            time.sleep(0.1)
        assert status["resident_images"] == 3 * len(monitors), status
        assert status["resident_textures"] == 3, status
        assert status["texture_uploads"] == 3, status
        print("PASS: prepared images load through the atomic manifest")

        stale = cache / ("a" * 64 + ".bmp")
        Image.new("RGB", (640, 400), (1, 2, 3)).save(stale)
        unrelated = cache / "personal.bmp"
        unrelated.write_bytes(b"preserve unrelated files")
        linked = cache / ("b" * 64 + ".bmp")
        linked.symlink_to(unrelated)
        shared = {
            name: {**images, "4": images["1"]} for name, images in prepared.items()
        }
        before = status["manifest_loads"]
        with (session / "workspace-wallpapers.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            publish(shared)
            time.sleep(0.25)
            assert json.loads(ctl("hyprmosaic:status"))["manifest_loads"] == before
            assert stale.exists(), "Cleanup raced with a locked preparation"
        status = wait_loaded(before)
        assert status["resident_images"] == 4 * len(monitors)
        assert status["resident_textures"] == 3 and status["texture_uploads"] == 3
        wait_removed(stale)
        assert unrelated.read_bytes() == b"preserve unrelated files"
        assert linked.is_symlink()
        print(
            "PASS: shared textures, nonblocking preparation lock, and safe generated-cache cleanup"
        )

        moved = {
            name: {"1": images["1"], "2": images["3"], "3": images["2"]}
            for name, images in prepared.items()
        }
        status = update(moved)
        assert status["texture_uploads"] == 3, status
        status = update(prepared)
        assert status["texture_uploads"] == 3, status
        print("PASS: reassignment between workspaces reuses existing GPU uploads")

        stale.write_bytes(unrelated.read_bytes())
        incomplete = {
            name: {**images, "1": str(cache / ("c" * 64 + ".bmp"))}
            for name, images in prepared.items()
        }
        status = update(incomplete)
        time.sleep(0.15)
        assert stale.exists(), "Incomplete replacement must not authorize pruning"
        status = update(prepared)
        wait_removed(stale)
        assert status["texture_uploads"] == 3
        print(
            "PASS: failed replacements preserve old textures and defer cleanup until recovery"
        )

        def capture():
            screenshot = root / "frame.png"
            subprocess.run(
                [grim, "-o", monitors[0]["name"], str(screenshot)],
                env=env,
                check=True,
                timeout=5,
            )
            with Image.open(screenshot) as image:
                return image.convert("RGB")

        def check_pixels(expected):
            frame = capture()
            pixel = frame.getpixel((frame.width // 2, frame.height // 2))
            assert all(abs(a - b) < 8 for a, b in zip(pixel, expected)), (
                "Wrong rendered pixel",
                pixel,
                expected,
            )

        check_pixels((91, 83, 67))
        print("PASS: workspace 1 renders the correct mid-tone over a light fallback")

        # Odd width exercises BMP row padding. Different quadrants catch row
        # inversion, channel swaps and opacity errors in the prepared loader.
        original = Path(prepared[monitors[0]["name"]]["1"])
        original_bytes = original.read_bytes()
        pattern_path = cache / (
            hashlib.sha256(b"row-padding-pattern").hexdigest() + ".bmp"
        )
        pattern = Image.new("RGB", (641, 401))
        colors = ((20, 90, 150), (130, 50, 70), (70, 130, 50), (90, 60, 140))
        for box, color in zip(
            ((0, 0, 320, 200), (320, 0, 641, 200),
             (0, 200, 320, 401), (320, 200, 641, 401)),
            colors,
        ):
            pattern.paste(color, box)
        pattern.save(pattern_path)
        patterned = {
            name: {**images, "1": str(pattern_path)}
            for name, images in prepared.items()
        }
        update(patterned)

        def check_pattern():
            frame = capture()
            for (x, y), expected in zip(((1, 1), (3, 1), (1, 3), (3, 3)), colors):
                pixel = frame.getpixel((frame.width * x // 4, frame.height * y // 4))
                assert all(abs(a - b) < 8 for a, b in zip(pixel, expected)), (
                    pixel, expected,
                )

        check_pattern()
        print("PASS: padded BMP rows retain orientation, RGB channels and opaque pixels")
        pattern_bytes = pattern_path.read_bytes()
        uploads = json.loads(ctl("hyprmosaic:status"))["texture_uploads"]
        invalid_path = cache / (hashlib.sha256(b"invalid-bmp").hexdigest() + ".bmp")
        malformed = [pattern_bytes[:20], pattern_bytes[:-1], b"XX" + pattern_bytes[2:]]
        for offset, fmt, value in (
            (2, "I", 0), (10, "I", 55), (14, "I", 124),
            (18, "i", -641), (22, "i", 0), (22, "i", 2147483647),
            (26, "H", 2), (28, "H", 32), (30, "I", 1),
        ):
            invalid = bytearray(pattern_bytes)
            struct.pack_into("<" + fmt, invalid, offset, value)
            malformed.append(invalid)
        for invalid in malformed:
            invalid_path.write_bytes(invalid)
            status = update({
                name: {**images, "1": str(invalid_path)}
                for name, images in prepared.items()
            })
            assert status["texture_uploads"] == uploads, status
            check_pattern()
        # The original may have been pruned after the valid pattern loaded.
        original.write_bytes(original_bytes)
        update(prepared)
        check_pixels((91, 83, 67))
        print(
            "PASS: malformed BMP replacements preserve resident pixels and recover normally"
        )

        assert ctl("eval", "hl.dispatch(hl.dsp.focus({workspace=2}))").strip() == "ok"
        moving = False
        for _ in range(12):
            status = json.loads(ctl("hyprmosaic:status"))
            draws = next(iter(status["draws"].values()), [])
            if len(draws) == 2 and any(abs(d["x"]) > 1 for d in draws):
                moving = True
                break
            time.sleep(0.015)
        assert moving, status
        print("PASS: both wallpaper textures move during an empty-workspace switch")
        time.sleep(0.6)
        check_pixels((40, 80, 160))
        print("PASS: workspace 2 renders the correct mid-tone over a light fallback")
        # Zero-alpha RGB can look plausible over black but adds to a light clear.
        for _ in range(8):
            check_pixels((40, 80, 160))
        print("PASS: repeated screenshot redraws preserve mid-tone colors")
        assert ctl("eval", "hl.dispatch(hl.dsp.focus({workspace=1}))").strip() == "ok"
        time.sleep(0.6)
        # The real bug appears only when the next request interrupts a slide.
        # Sample rendered scanlines, not just the plugin's list of draw calls.
        sequence = [
            (2, 0.06),
            (1, 0.04),
            (2, 0.1),
            (1, 0.03),
            (3, 0.08),
            (2, 0.04),
            (1, 0.15),
            (3, 0.03),
        ]
        for number, delay in sequence:
            ctl("eval", f"hl.dispatch(hl.dsp.focus({{workspace={number}}}))")
            time.sleep(delay)
            for _ in range(3):
                frame = capture()
                for y in (frame.height // 3, 2 * frame.height // 3):
                    pale = [
                        x
                        for x in range(frame.width)
                        if min(frame.getpixel((x, y))) > 220
                    ]
                    assert not pale, (
                        "Exposed fallback during rapid switch",
                        number,
                        y,
                        pale[:10],
                    )
                time.sleep(0.015)
        time.sleep(0.6)
        check_pixels((120, 50, 90))
        print(
            "PASS: rapid reversals/third-workspace switches never expose the pale fallback"
        )
        ctl("eval", "hl.dispatch(hl.dsp.focus({workspace=1}))")
        time.sleep(0.6)
        original_path = Path(prepared[monitors[0]["name"]]["1"])
        original_bytes = original_path.read_bytes()
        replacement = cache / (hashlib.sha256(b"replacement").hexdigest() + ".bmp")
        replacement.write_bytes(original_bytes)
        changed = {
            name: {**images, "1": str(replacement)} for name, images in prepared.items()
        }
        before_uploads = json.loads(ctl("hyprmosaic:status"))["texture_uploads"]
        status = update(changed)
        assert status["texture_uploads"] == before_uploads + 1, status
        wait_removed(original_path)
        assert replacement.exists()
        check_pixels((91, 83, 67))
        original_path.write_bytes(original_bytes)
        status = update(prepared)
        wait_removed(replacement)
        check_pixels((91, 83, 67))
        print(
            "PASS: actual replaced files are reclaimed after upload with identical rendered pixels"
        )

        # Staging must never reveal a partially replaced set. Also supersede
        # an in-flight manifest to exercise cancellation and cache ownership.
        originals = {
            path: Path(path).read_bytes()
            for images in prepared.values() for path in images.values()
        }
        staged_paths = {}
        for number in range(1, 13):
            path = cache / (
                hashlib.sha256(f"staged-{number}".encode()).hexdigest() + ".bmp"
            )
            Image.new("RGB", (640, 400), (30, 100, number * 10)).save(path)
            staged_paths[str(number)] = str(path)
        staged_manifest = {mon["name"]: staged_paths for mon in monitors}

        def wait_staging(before):
            for _ in range(100):
                status = json.loads(ctl("hyprmosaic:status"))
                if status["texture_uploads"] > before["texture_uploads"]:
                    assert status["manifest_loads"] == before["manifest_loads"], status
                    assert status["resident_images"] == before["resident_images"], status
                    assert status["draws"] == before["draws"], status
                    return
                time.sleep(0.005)
            raise AssertionError("No staged upload observed")

        before = json.loads(ctl("hyprmosaic:status"))
        publish(staged_manifest)
        wait_staging(before)
        final_path = cache / (
            hashlib.sha256(b"superseding-manifest").hexdigest() + ".bmp"
        )
        Image.new("RGB", (640, 400), (65, 85, 105)).save(final_path)
        final_manifest = {
            name: {**images, "1": str(final_path)}
            for name, images in prepared.items()
        }
        publish(final_manifest)
        status = wait_loaded(before["manifest_loads"])
        assert status["resident_images"] == 3 * len(monitors), status
        assert status["manifest_loads"] == before["manifest_loads"] + 1, status
        check_pixels((65, 85, 105))
        for path, content in originals.items():
            Path(path).write_bytes(content)
        update(prepared)
        check_pixels((91, 83, 67))
        print(
            "PASS: staged uploads keep old assignments visible and discard superseded manifests"
        )

        for path in staged_paths.values():
            Image.new("RGB", (640, 400), (60, 80, 100)).save(path)
        before = json.loads(ctl("hyprmosaic:status"))
        publish(staged_manifest)
        wait_staging(before)
        publish(prepared)
        assert not ctl("configerrors").strip()
        ctl("plugin", "unload", plugin)
        assert not json.loads(ctl("-j", "plugin", "list"))
        ctl("plugin", "load", plugin)
        time.sleep(0.25)
        assert json.loads(ctl("hyprmosaic:status"))["resident_images"] == 3 * len(
            monitors
        )
        print(
            "PASS: unload during staging cancels pending work and reload retains usable assignments"
        )
    except Exception:
        log.seek(0)
        print(log.read()[-12000:])
        for extra in (root / "hypr").glob("*/hyprland.log"):
            print(extra.read_text()[-12000:])
        raise
    finally:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
