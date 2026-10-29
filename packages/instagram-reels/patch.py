#!/usr/bin/env python3
"""Patch local original APKs; app binaries, accounts and signing keys stay outside Nix."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(prog="instagram-reels-patch", description=__doc__)
    for flag in ("java", "cli", "bundle", "clone-bundle", "supported"):
        parser.add_argument("--" + flag, required=True, help=argparse.SUPPRESS)
    parser.add_argument("apk_directory", type=Path, help="directory containing the preserved original APK splits")
    parser.add_argument("--output", type=Path, help="output APK; defaults to the private application state directory")
    args = parser.parse_args()
    os.umask(0o077)
    supported = json.loads(Path(args.supported).read_text())
    for name, expected in supported["inputs"].items():
        source = args.apk_directory / name
        if not source.is_file():
            parser.error(f"Missing original APK: {source}")
        with source.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != expected:
            parser.error(f"{source} does not match the tested original APK. Review and retest a new version before changing supported.json.")

    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "instagram-reels"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    output = (args.output or state / "instagram-reels.apk").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, MORPHE_DATA_DIR=str(state / "morphe"))
    with tempfile.TemporaryDirectory(prefix="build-", dir=state) as temporary:
        archive = Path(temporary) / "original.apkm"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as bundle:
            for name in supported["inputs"]:
                bundle.write(args.apk_directory / name, name)
        command = [
            args.java, "-Xmx2304m", "-XX:ActiveProcessorCount=2", "-jar", args.cli,
            "patch", str(archive), "-p", args.bundle,
            "-e", "Local hide Reels navigation", "-e", "Local stop Reels scrolling",
            "-p", args.clone_bundle, "-e", "Clone", "-O", f"appName={supported['label']}",
            "-O", f"packageName={supported['package']}",
            "--exclusive", "--force", "--validate", "--bytecode-mode", "FULL",
            "-r", str(state / "last-build.json"), "-o", str(output),
        ]
        # --force is needed for the generic Clone patch's older version metadata.
        # Exact original hashes and in-patch version/code checks guard the local hooks.
        result = subprocess.run(command, env=environment)
        if result.returncode:
            raise SystemExit(result.returncode)
    key = state / "morphe/morphe.keystore"
    if key.exists():
        key.chmod(0o600)
    output.chmod(0o600)
    print(f"Built {supported['label']}: {output}")
    print("Installation and account sign-in are separate; this command does not modify Android.")


if __name__ == "__main__":
    main()
