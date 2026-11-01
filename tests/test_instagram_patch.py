"""Protect the working APK and signing identity when a manual patch build fails."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile


spec = importlib.util.spec_from_file_location(
    "instagram_patch", Path(__file__).parents[1] / "packages/instagram-reels/patch.py"
)
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)


class InstagramPatchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.state = self.root / "state/instagram-reels"
        self.state.mkdir(parents=True)
        self.output = self.state / "instagram-reels.apk"
        self.output.write_bytes(b"working APK")
        self.report = self.state / "last-build.json"
        self.report.write_bytes(b"previous report")
        self.key = self.state / "morphe/morphe.keystore"
        self.key.parent.mkdir()
        self.key.write_bytes(b"existing private key")
        self.originals = self.root / "original"
        self.originals.mkdir()
        (self.originals / "base.apk").write_bytes(b"original APK")
        supported = self.root / "supported.json"
        supported.write_text(json.dumps({
            "version": "453.0.0.57.79", "versionCode": "385914559",
            "package": "com.instagram.android.piko", "label": "Instagram",
            "inputs": {"base.apk": patch.sha256(self.originals / "base.apk")},
        }))
        self.argv = ["instagram-reels-patch", "--java", "java", "--supported", str(supported)]
        for name in ("cli", "bundle", "clone-bundle"):
            artifact = self.root / name
            artifact.write_bytes(name.encode())
            self.argv.extend(["--" + name, str(artifact)])
        self.argv.append(str(self.originals))

    def successful_command(self, command, **kwargs):
        output = Path(command[command.index("-o") + 1])
        with zipfile.ZipFile(output, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"test manifest")
        report = {
            "success": True, "packageVersion": "453.0.0.57.79",
            "outputPath": str(output), "appliedPatches": list(patch.PATCHES),
            "failedPatches": [],
            "stepResults": [{"step": step, "success": True}
                            for step in ("PATCHING", "REBUILDING", "SIGNING")],
        }
        Path(command[command.index("-r") + 1]).write_text(json.dumps(report))
        return subprocess.CompletedProcess(command, 0)

    def run_build(self, command=None):
        with (
            mock.patch.dict(os.environ, {"XDG_STATE_HOME": str(self.root / "state")}),
            mock.patch("sys.argv", self.argv),
            mock.patch.object(patch.subprocess, "run", side_effect=command or self.successful_command) as run,
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            patch.main()
        return run

    def assert_working_preserved(self):
        self.assertEqual(self.output.read_bytes(), b"working APK")
        self.assertEqual(self.report.read_bytes(), b"previous report")
        self.assertEqual(self.key.read_bytes(), b"existing private key")
        self.assertFalse(list(self.state.glob(".instagram-build-*")))

    def test_success_preserves_previous_and_records_exact_inputs(self):
        run = self.run_build()
        self.assertTrue(zipfile.is_zipfile(self.output))
        self.assertEqual(self.output.with_name("instagram-reels.previous.apk").read_bytes(), b"working APK")
        report = json.loads(self.report.read_text())
        self.assertEqual(report["outputPath"], str(self.output))
        self.assertEqual(report["outputSha256"], patch.sha256(self.output))
        self.assertEqual(set(report["patchInputsSha256"]), {"cli", "bundle", "clone-bundle"})
        self.assertEqual(self.key.read_bytes(), b"existing private key")
        self.assertEqual(self.key.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.output.stat().st_mode & 0o777, 0o600)
        command = run.call_args.args[0]
        self.assertEqual([command[i + 1] for i, arg in enumerate(command) if arg == "-e"], list(patch.PATCHES))
        self.assertFalse(list(self.state.glob(".instagram-build-*")))

    def test_failed_command_cannot_overwrite_working_apk_or_report(self):
        def fail(command, **kwargs):
            Path(command[command.index("-o") + 1]).write_bytes(b"partial APK")
            return subprocess.CompletedProcess(command, 1)
        with self.assertRaises(SystemExit):
            self.run_build(fail)
        self.assert_working_preserved()

    def test_incomplete_patch_set_is_rejected(self):
        def incomplete(command, **kwargs):
            result = self.successful_command(command, **kwargs)
            report_path = Path(command[command.index("-r") + 1])
            report = json.loads(report_path.read_text())
            report["appliedPatches"].remove("Local hide messaging Blend button")
            report_path.write_text(json.dumps(report))
            return result
        with self.assertRaises(SystemExit):
            self.run_build(incomplete)
        self.assert_working_preserved()

    def test_wrong_input_is_rejected_before_running_patcher(self):
        (self.originals / "base.apk").write_bytes(b"different release")
        run = mock.Mock(side_effect=AssertionError("Patcher must not run"))
        with self.assertRaises(SystemExit):
            self.run_build(run)
        run.assert_not_called()
        self.assert_working_preserved()

    def test_missing_key_cannot_silently_change_signing_identity(self):
        self.key.unlink()
        with self.assertRaises(SystemExit):
            self.run_build()
        self.assertEqual(self.output.read_bytes(), b"working APK")
        self.assertFalse(self.key.exists())


if __name__ == "__main__":
    unittest.main()
