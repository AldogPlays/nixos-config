"""Run only a disposable nested compositor; never load plugins into the host."""

import json
import os
from pathlib import Path
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
                image = cache / f"test-{number}.bmp"
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

        publish(prepared)
        for _ in range(50):
            status = json.loads(ctl("hyprmosaic:status"))
            if status["resident_images"] == 3 * len(monitors):
                break
            time.sleep(0.1)
        assert status["resident_images"] == 3 * len(monitors), status
        print("PASS: prepared images load through the atomic manifest")

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
        assert not ctl("configerrors").strip()
        ctl("plugin", "unload", plugin)
        assert not json.loads(ctl("-j", "plugin", "list"))
        ctl("plugin", "load", plugin)
        time.sleep(0.25)
        assert json.loads(ctl("hyprmosaic:status"))["resident_images"] == 3 * len(
            monitors
        )
        print(
            "PASS: unload/reload retains usable assignments without compositor restart"
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
