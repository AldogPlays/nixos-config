"""One-shot wallpaper reconciliation; Hyprland owns the events and timer."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import random
import re
import subprocess
import time

from PIL import Image, ImageOps


# The pinned awww package does not enable its optional AVIF/JPEG XL decoders.
FORMATS = {".png", ".jpg", ".jpeg", ".webp"}


def discover(directory):
    # Do not follow directory symlinks or interpret image names as shell code.
    images = set()
    for root, _, files in os.walk(directory):
        for name in files:
            path = Path(root, name).resolve()
            if (
                path.suffix.lower() in FORMATS
                and path.is_file()
                and not any(char in str(path) for char in "\n\r")
            ):
                images.add(str(path))
    return sorted(images)


def assign(keys, images, previous):
    """Unique choices while possible; avoid a workspace's previous image."""
    result = {}
    unused = images.copy()
    for key in keys:
        pool = unused or images
        choices = [image for image in pool if image != previous.get(key)] or pool
        image = random.choice(choices)
        result[key] = image
        if image in unused:
            unused.remove(image)
    # If the last unique choice repeated its old image, exchange with a peer.
    for key in keys:
        if result[key] == previous.get(key):
            peers = [
                other
                for other in keys
                if result[other] != result[key] and result[key] != previous.get(other)
            ]
            if peers:
                other = random.choice(peers)
                result[key], result[other] = result[other], result[key]
    return result


def command(executable, *args):
    return subprocess.check_output(
        [executable, *args], text=True, stderr=subprocess.PIPE, timeout=10
    )


def prepare_image(source, size, directory):
    source = Path(source)
    stat = source.stat()
    identity = f"lanczos-cover-v1:{source}:{stat.st_size}:{stat.st_mtime_ns}:{size}"
    target = directory / (hashlib.sha256(identity.encode()).hexdigest() + ".bmp")
    if not target.exists():
        # One-time high-quality cover resize, not a cheaper filter on every switch.
        with Image.open(source) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            image = ImageOps.fit(image, size, Image.Resampling.LANCZOS)
            temporary = target.with_suffix(".tmp")
            image.save(temporary, format="BMP")
            temporary.replace(target)
    return str(target)


def publish_assignments(state_path, epoch, assignments, prepared):
    # Plain data, not executable Lua: one small, atomically replaced file per ID.
    # Lua can read this without starting Python or querying compositor/backend IPC.
    root = state_path.with_suffix("")
    for name, images in prepared.items():
        # Encoded output names cannot escape the private generated-cache directory.
        directory = root / name.encode().hex()
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        keys = set(assignments) | {
            path.name for path in directory.iterdir() if path.name.lstrip("-").isdigit()
        }
        for key in keys:
            path = directory / str(int(key))
            content = f"{epoch}\n{assignments.get(key, '')}\n{images.get(key, '')}"
            if path.exists() and path.read_text() == content:
                continue
            temporary = path.with_suffix(".tmp")
            temporary.write_text(content)
            temporary.replace(path)


def reconcile(directory, state_path, interval, run, now=None):
    now = time.time() if now is None else now
    epoch = int(now // interval)
    try:
        state = json.loads(state_path.read_text())
        if not isinstance(state, dict) or not isinstance(
            state.get("assignments"), dict
        ):
            state = {}
    except (OSError, ValueError):
        state = {}

    monitors = json.loads(run("-j", "monitors"))
    workspaces = json.loads(run("-j", "workspaces"))
    # Reserve the ten configured workspaces even when Hyprland destroys empty ones.
    keys = list(
        dict.fromkeys(
            [str(number) for number in range(1, 11)]
            + [str(ws["id"]) for ws in workspaces if ws["id"] > 0]
            + [str(mon["activeWorkspace"]["id"]) for mon in monitors]
            + list(state.get("assignments", {}))
        )
    )
    previous = state.get("assignments", {})
    refresh = state.get("epoch") != epoch or state.get("directory") != str(directory)
    images = [
        image
        for image in state.get("images", [])
        if Path(image).suffix.lower() in FORMATS
    ]
    if (
        refresh
        or not images
        or any(not Path(image).is_file() for image in previous.values())
    ):
        images = discover(directory)
    assignments = (
        {}
        if refresh
        else {key: image for key, image in previous.items() if image in images}
    )
    if images:
        missing = [key for key in keys if key not in assignments]
        free = [image for image in images if image not in assignments.values()]
        assignments.update(assign(missing, free or images, previous))

    # Query actual backend state: restarts/reloads must not leave a stale cache.
    outputs = json.loads(run("awww", "query", "--json")).get("", [])
    cache = state_path.parent / "workspace-wallpaper-images"
    cache.mkdir(mode=0o700, exist_ok=True)
    while True:
        prepared, failed = {}, set()
        for output in outputs:
            size = (
                round(output["width"] * output["scale"]),
                round(output["height"] * output["scale"]),
            )
            if min(size) <= 0:
                continue
            rendered = prepared[output["name"]] = {}
            for key, image in assignments.items():
                try:
                    rendered[key] = prepare_image(image, size, cache)
                except (OSError, ValueError, Image.DecompressionBombError):
                    failed.add(image)
        if not failed:
            break
        # A broken/oversized image must not break every future rotation/startup.
        images = [image for image in images if image not in failed]
        assignments = {
            key: image for key, image in assignments.items() if image not in failed
        }
        if images:
            missing = [key for key in keys if key not in assignments]
            free = [image for image in images if image not in assignments.values()]
            assignments.update(assign(missing, free or images, previous))
    # Publish only once all assigned images are ready. Previous images stay visible
    # while preparation runs, and ordinary switches never perform this work.
    publish_assignments(state_path, epoch, assignments, prepared)
    # Preparation can take seconds; never apply a workspace snapshot from before it.
    monitors = json.loads(run("-j", "monitors"))
    active = {
        output["name"]: output["displaying"].get("image")
        for output in json.loads(run("awww", "query", "--json")).get("", [])
    }
    for monitor in monitors:
        # Special workspaces overlay the regular workspace and keep its backdrop.
        name = monitor["name"]
        image = prepared.get(name, {}).get(str(monitor["activeWorkspace"]["id"]))
        if image and active.get(name) != image:
            run(
                "awww",
                "img",
                "--transition-type",
                "none",
                "--resize",
                "no",
                "--outputs",
                name,
                "--",
                image,
            )

    old_prepared = state.get("prepared", {})
    retained = (
        list({image for output in old_prepared.values() for image in output.values()})
        if prepared != old_prepared
        else state.get("retained", [])
    )
    state = {
        "epoch": epoch,
        "directory": str(directory),
        "images": images,
        "assignments": assignments,
        "prepared": prepared,
        "retained": retained,
    }
    temporary = state_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_path)
    # Retain one previous set for in-flight requests; bound storage to two sets.
    # Only our generated BMPs are pruned, never originals or unrelated files.
    keep = {image for output in prepared.values() for image in output.values()} | set(
        retained
    )
    for path in cache.iterdir():
        if re.fullmatch(r"[0-9a-f]{64}\.bmp", path.name) and str(path) not in keep:
            path.unlink()
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--hyprctl", required=True)
    parser.add_argument("--awww", required=True)
    parser.add_argument("--interval", type=int, default=900)
    parser.add_argument(
        "--wait", action="store_true", help="wait briefly for backend startup"
    )
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("interval must be positive")
    session = Path(
        os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    )
    socket = Path(
        os.environ["XDG_RUNTIME_DIR"],
        Path(os.environ["WAYLAND_DISPLAY"]).name + "-awww-daemon.sock",
    )
    if args.wait:
        for _ in range(40):
            if socket.exists():
                break
            time.sleep(0.25)
    if not socket.exists():
        return
    # Serialize short-lived invocations; read monitor state only after the lock.
    with (session / "workspace-wallpapers.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        reconcile(
            args.directory,
            session / "workspace-wallpapers.json",
            args.interval,
            lambda *parts: (
                command(args.awww, *parts[1:])
                if parts[0] == "awww"
                else command(args.hyprctl, *parts)
            ),
        )


if __name__ == "__main__":
    main()
