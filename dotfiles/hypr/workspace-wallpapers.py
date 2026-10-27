"""One-shot wallpaper reconciliation; Hyprland owns the events and timer."""

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import stat
import struct
import subprocess
import tempfile
import time

from PIL import Image, ImageOps


# Keep the established collection formats; preparation normalizes them to RGB BMP.
FORMATS = {".png", ".jpg", ".jpeg", ".webp"}
CACHE_LIMIT = 512 * 1024 * 1024


def copy_atomic(source, target):
    """Independent copies: pruning either cache must not affect the other."""
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as temporary:
        path = Path(temporary.name)
        try:
            with source.open("rb") as stream:
                shutil.copyfileobj(stream, temporary)
            temporary.close()
            path.replace(target)
        finally:
            path.unlink(missing_ok=True)


def valid_bmp(path, size):
    """Check our RGB BMP header and payload length without decoding pixels."""
    if path.is_symlink() or not path.is_file():
        return False
    with path.open("rb") as stream:
        header = stream.read(54)
        length = os.fstat(stream.fileno()).st_size
    width, height = size
    expected = 54 + ((width * 3 + 3) // 4 * 4) * height
    return (
        len(header) == 54
        and header[:2] == b"BM"
        and length == expected
        and struct.unpack_from("<I", header, 2)[0] == expected
        and struct.unpack_from("<IIiiHHI", header, 10)
        == (54, 40, width, height, 1, 24, 0)
    )


class PreparedCache:
    """Optional, bounded disk history; never publish these paths to the plugin."""

    def __init__(self, directory, limit=CACHE_LIMIT):
        self.directory = Path(directory)
        self.limit = limit

    @contextmanager
    def locked(self):
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (self.directory / ".lock").open("a") as lock:
            # Shared by sessions, held only for small prepared-file operations.
            fcntl.flock(lock, fcntl.LOCK_EX)
            yield

    def prune(self):
        entries = []
        for path in self.directory.iterdir():
            if re.fullmatch(r"[0-9a-f]{64}\.bmp", path.name):
                metadata = path.lstat()
                if stat.S_ISREG(metadata.st_mode):
                    entries.append((metadata.st_mtime_ns, path, metadata.st_size))
        total = sum(size for _, _, size in entries)
        for _, path, size in sorted(entries):
            if total <= self.limit:
                break
            path.unlink()
            total -= size

    def restore(self, target, size):
        try:
            with self.locked():
                cached = self.directory / target.name
                if not valid_bmp(cached, size):
                    return False
                copy_atomic(cached, target)
                cached.touch()
                self.prune()
                return True
        except OSError:
            # A missing/unwritable/full disk cache must not reject a good source.
            return False

    def store(self, source, size):
        try:
            with self.locked():
                cached = self.directory / source.name
                if not cached.is_symlink() and source.stat().st_size <= self.limit:
                    if not valid_bmp(cached, size):
                        copy_atomic(source, cached)
                    cached.touch()
                self.prune()
        except OSError:
            pass


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


def prepare_image(source, size, directory, persistent_cache=None, color_mode="color"):
    if color_mode not in ("color", "grayscale"):
        raise ValueError(f"Unsupported wallpaper color mode: {color_mode}")
    source = Path(source)
    stat = source.stat()
    identity = f"lanczos-cover-v1:{source}:{stat.st_size}:{stat.st_mtime_ns}:{size}"
    # Preserve existing color cache entries; grayscale has its own processing key.
    if color_mode == "grayscale":
        identity += ":grayscale-v1"
    target = directory / (hashlib.sha256(identity.encode()).hexdigest() + ".bmp")
    if not target.exists():
        if persistent_cache is not None and persistent_cache.restore(target, size):
            return str(target)
        # One-time high-quality cover resize, not a cheaper filter on every switch.
        with Image.open(source) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            image = ImageOps.fit(image, size, Image.Resampling.LANCZOS)
            if color_mode == "grayscale":
                image = ImageOps.grayscale(image).convert("RGB")
            temporary = target.with_suffix(".tmp")
            image.save(temporary, format="BMP")
            temporary.replace(target)
    if persistent_cache is not None:
        persistent_cache.store(target, size)
    return str(target)


def reconcile(
    directory, state_path, interval, run, now=None, persistent_cache=None, color_mode="color"
):
    if color_mode not in ("color", "grayscale"):
        raise ValueError(f"Unsupported wallpaper color mode: {color_mode}")
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

    # Hyprland reports physical mode dimensions. Odd transforms rotate the mode.
    outputs = monitors
    cache = state_path.parent / "workspace-wallpaper-images"
    cache.mkdir(mode=0o700, exist_ok=True)
    # Share results across equal-sized outputs, repeated assignments and retries.
    # Keep this per invocation so future updates still recheck source metadata.
    prepared_images, rejected = {}, set()
    while True:
        prepared, failed = {}, set()
        for output in outputs:
            size = (output["width"], output["height"])
            if output.get("transform", 0) % 2:
                size = size[::-1]
            if min(size) <= 0:
                continue
            rendered = prepared[output["name"]] = {}
            for key, image in assignments.items():
                if image in rejected:
                    failed.add(image)
                    continue
                try:
                    identity = (image, size)
                    if identity not in prepared_images:
                        prepared_images[identity] = prepare_image(
                            image, size, cache, persistent_cache,
                            color_mode=color_mode,
                        )
                    rendered[key] = prepared_images[identity]
                except (OSError, ValueError, Image.DecompressionBombError):
                    rejected.add(image)
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
    # Publish one atomic manifest, only after every selected image is ready.
    # The plugin watches this rename and swaps resident textures; no switch IPC.
    content = json.dumps(state)
    if not state_path.exists() or state_path.read_text() != content:
        temporary = state_path.with_suffix(".tmp")
        temporary.write_text(content)
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
    parser.add_argument("--interval", type=int, default=900)
    parser.add_argument("--cache-directory", type=Path, required=True)
    parser.add_argument("--cache-limit", type=int, default=CACHE_LIMIT)
    parser.add_argument("--color-mode", choices=("color", "grayscale"), default="color")
    args = parser.parse_args()
    if args.interval <= 0:
        parser.error("interval must be positive")
    if args.cache_limit < 0:
        parser.error("cache limit must not be negative")
    session = Path(
        os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    )
    # Serialize short-lived invocations; read monitor state only after the lock.
    with (session / "workspace-wallpapers.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        reconcile(
            args.directory,
            session / "workspace-wallpapers.json",
            args.interval,
            lambda *parts: command(args.hyprctl, *parts),
            persistent_cache=PreparedCache(args.cache_directory, args.cache_limit),
            color_mode=args.color_mode,
        )


if __name__ == "__main__":
    main()
