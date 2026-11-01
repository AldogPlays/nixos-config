#!/usr/bin/env python3
"""Patch local original APKs; app binaries, accounts and signing keys stay outside Nix."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


PATCHES = (
    "Local hide Home and Reels navigation",
    "Local stop Reels scrolling",
    "Local hide messaging Blend button",
    "Clone",
)


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


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
        actual = sha256(source)
        if actual != expected:
            parser.error(f"{source} does not match the tested original APK. Review and retest a new version before changing supported.json.")

    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "instagram-reels"
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    output = (args.output or state / "instagram-reels.apk").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    key = state / "morphe/morphe.keystore"
    report_path = state / "last-build.json"
    if (output.exists() or report_path.exists()) and not key.is_file():
        parser.error("The previous signing key is missing. Restore its private backup before building an update.")
    environment = dict(os.environ, MORPHE_DATA_DIR=str(state / "morphe"))
    # Stage beside the destination so a failed build cannot overwrite the working
    # APK, and the final rename remains atomic even with a custom output path.
    with tempfile.TemporaryDirectory(prefix=".instagram-build-", dir=output.parent) as temporary:
        workspace = Path(temporary)
        archive = workspace / "original.apkm"
        candidate = workspace / "patched.apk"
        report_file = workspace / "report.json"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_STORED) as bundle:
            for name in supported["inputs"]:
                bundle.write(args.apk_directory / name, name)
        command = [
            args.java, "-Xmx2304m", "-XX:ActiveProcessorCount=2", "-jar", args.cli,
            "patch", str(archive), "-p", args.bundle,
            *[argument for name in PATCHES[:-1] for argument in ("-e", name)],
            "-p", args.clone_bundle, "-e", "Clone", "-O", f"appName={supported['label']}",
            "-O", f"packageName={supported['package']}",
            "--exclusive", "--force", "--validate", "--bytecode-mode", "FULL",
            "-r", str(report_file), "-o", str(candidate),
        ]
        # --force is needed for the generic Clone patch's older version metadata.
        # Exact original hashes and in-patch version/code checks guard the local hooks.
        result = subprocess.run(command, env=environment)
        if result.returncode:
            raise SystemExit(result.returncode)
        report = json.loads(report_file.read_text())
        applied = report.get("appliedPatches", [])
        steps = report.get("stepResults", [])
        if not (
            report.get("success") is True
            and report.get("packageVersion") == supported["version"]
            and len(applied) == len(PATCHES) and set(applied) == set(PATCHES)
            and not report.get("failedPatches")
            and {step["step"] for step in steps if step.get("success") is True}
            >= {"PATCHING", "REBUILDING", "SIGNING"}
            and all(step.get("success") is True for step in steps)
            and candidate.is_file() and zipfile.is_zipfile(candidate)
            and key.is_file()
        ):
            raise SystemExit("Build report or signed APK is incomplete; the previous APK was preserved.")
        key.chmod(0o600)
        candidate.chmod(0o600)
        report.update(
            outputPath=str(output),
            outputSha256=sha256(candidate),
            clonePackage=supported["package"],
            versionCode=supported["versionCode"],
            originalSha256=supported["inputs"],
            patchInputsSha256={
                name: sha256(getattr(args, name.replace("-", "_")))
                for name in ("cli", "bundle", "clone-bundle")
            },
        )
        # Prepare all report data before publishing either artifact. Its state
        # directory may be on a different filesystem from a custom APK output.
        with tempfile.NamedTemporaryFile(mode="w", dir=state, delete=False) as stream:
            json.dump(report, stream, indent=2)
            stream.write("\n")
            staged_report = Path(stream.name)
        try:
            if output.exists():
                previous = workspace / "previous.apk"
                shutil.copy2(output, previous)
                os.replace(previous, output.with_name(output.stem + ".previous" + output.suffix))
            os.replace(candidate, output)
            os.replace(staged_report, report_path)
        finally:
            staged_report.unlink(missing_ok=True)
    print(f"Built {supported['label']}: {output}")
    print("Installation and account sign-in are separate; this command does not modify Android.")


if __name__ == "__main__":
    main()
