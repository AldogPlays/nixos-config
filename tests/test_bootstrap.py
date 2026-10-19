"""Bootstrap planning and failure handling; never modify the installed system."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import shutil
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


ROOT = Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location(
    "bootstrap", ROOT / "scripts/bootstrap.py"
)
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


def host_data():
    return {
        "bootstrapSchema": 1,
        "username": "tester",
        "homeDirectory": "/home/tester",
        "homeStateVersion": "26.05",
        "hostName": "another-pc",
        "stateVersion": "25.11",
        "mutableUsers": True,
        "userIsNormal": True,
        "initrdSystemd": True,
        "unsupportedBoot": False,
        "kernelParams": [],
        "resumeDevice": "",
        "videoDrivers": ["modesetting"],
        "graphics": {
            "enable32Bit": False,
            "extraPackageNames": [],
            "extraPackageNames32": [],
        },
        "nvidia": {},
        "bootLoader": {
            "systemd-boot": {"enable": True, "configurationLimit": 10},
            "grub": {
                "enable": False,
                "devices": [],
                "efiSupport": False,
                "efiInstallAsRemovable": False,
                "enableCryptodisk": False,
                "useOSProber": False,
            },
            "efi": {"canTouchEfiVariables": True, "efiSysMountPoint": "/boot"},
        },
    }


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        nixos = mock.patch.object(bootstrap, "running_nixos", return_value=True)
        nixos.start()
        self.addCleanup(nixos.stop)
        release = mock.patch.object(
            bootstrap, "installed_release", return_value="26.05"
        )
        release.start()
        self.addCleanup(release.stop)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.configuration = self.root / "configuration.nix"
        self.configuration.write_text("{}")
        self.hardware = self.root / "hardware-configuration.nix"
        self.hardware.write_text(
            '{ fileSystems."/".device = "/dev/disk/by-label/new-pc"; }'
        )
        self.host = host_data()

    def arguments(self):
        return [
            "--project-source",
            str(ROOT),
            "--nixpkgs-source",
            "/pinned/nixpkgs",
            "--configuration",
            str(self.configuration),
            "--user",
            "tester",
        ]

    def fake_nix(self, *arguments, **kwargs):
        if arguments[0] == "eval":
            return SimpleNamespace(stdout=json.dumps(self.host))
        if arguments[:2] == ("flake", "lock"):
            (Path(str(arguments[2]).removeprefix("path:")) / "flake.lock").write_text(
                "{}"
            )
        return SimpleNamespace(returncode=0)

    def test_preserves_host_identity_hardware_and_compatibility_baseline(self):
        stage = self.root / "stage"
        stage.mkdir()
        bootstrap.write_configuration(stage, ROOT, self.hardware, self.host)
        self.assertEqual(
            (stage / "project-hardware.nix").read_bytes(), self.hardware.read_bytes()
        )
        self.assertEqual(
            json.loads((stage / "project-host.json").read_text()), self.host
        )
        flake = (stage / "flake.nix").read_text()
        self.assertIn("project.lib.mkPortableSystem", flake)
        self.assertNotIn("37a5048c", flake)
        self.assertNotIn('username = "jeffreyc"', flake)
        self.assertNotIn('homeDirectory = "/home/jeffreyc"', flake)

    def test_accepts_bios_grub_without_forcing_efi(self):
        self.host["bootLoader"]["systemd-boot"]["enable"] = False
        self.host["bootLoader"]["grub"].update(
            enable=True, devices=["/dev/disk/by-id/target-disk"]
        )
        self.host["bootLoader"]["efi"]["canTouchEfiVariables"] = False
        bootstrap.validate_host(self.host)

    def test_newer_installed_os_is_rejected_with_older_state_version(self):
        self.host["stateVersion"] = "25.11"
        with (
            mock.patch.object(bootstrap, "installed_release", return_value="26.11"),
            mock.patch.object(bootstrap, "nix") as nix,
            mock.patch.object(bootstrap, "privileged") as privileged,
        ):
            with self.assertRaisesRegex(ValueError, "newer installation"):
                bootstrap.main([*self.arguments(), "--apply"])
        nix.assert_not_called()
        privileged.assert_not_called()

    def test_invalid_release_is_rejected(self):
        for release in ("", "rolling", "26.05pre"):
            with self.subTest(release=release), self.assertRaises(ValueError):
                bootstrap.validate_release(release)

    def test_rejects_unsupported_layouts_accounts_and_downgrades(self):
        for key, value in [
            ("unsupportedBoot", True),
            ("mutableUsers", False),
            ("unsupportedGraphics", True),
            ("userIsNormal", False),
            ("username", "root${expression}"),
            ("homeDirectory", "relative"),
            ("stateVersion", "26.11"),
        ]:
            with self.subTest(key=key):
                host = copy.deepcopy(self.host)
                host[key] = value
                with self.assertRaises(ValueError):
                    bootstrap.validate_host(host)
        self.host["bootLoader"]["grub"]["enable"] = True
        with self.assertRaises(ValueError):
            bootstrap.validate_host(self.host)

    def test_existing_unrelated_flake_and_symlink_are_preserved(self):
        destination = self.root / "target"
        destination.mkdir()
        (destination / "flake.nix").write_text("original")
        with self.assertRaises(ValueError):
            bootstrap.check_destination(destination)
        self.assertEqual((destination / "flake.nix").read_text(), "original")
        (destination / "project-host.json").write_text('{"bootstrapSchema":1}')
        bootstrap.check_destination(destination)
        link = self.root / "linked"
        link.symlink_to(destination)
        with self.assertRaises(ValueError):
            bootstrap.check_destination(link)

    def test_preview_exports_inspectable_files_without_privileged_actions(self):
        output = self.root / "preview"
        with (
            mock.patch.object(
                bootstrap.pwd,
                "getpwnam",
                return_value=SimpleNamespace(pw_uid=1000, pw_dir="/home/tester"),
            ),
            mock.patch.object(bootstrap, "nix", side_effect=self.fake_nix) as nix,
            mock.patch.object(bootstrap, "install") as install,
            mock.patch.object(bootstrap, "privileged") as privileged,
        ):
            bootstrap.main([*self.arguments(), "--output", str(output)])
        install.assert_not_called()
        privileged.assert_not_called()
        self.assertIn("--dry-run", nix.call_args.args)
        self.assertEqual({path.name for path in output.iterdir()}, set(bootstrap.FILES))

    def test_build_failure_never_installs(self):
        def fail_build(*args, **kwargs):
            if args[0] == "build":
                raise subprocess.CalledProcessError(1, ["nix", "build"])
            return self.fake_nix(*args, **kwargs)

        with (
            mock.patch.object(
                bootstrap.pwd,
                "getpwnam",
                return_value=SimpleNamespace(pw_uid=1000, pw_dir="/home/tester"),
            ),
            mock.patch.object(bootstrap, "nix", side_effect=fail_build),
            mock.patch.object(bootstrap, "check_destination"),
            mock.patch.object(bootstrap, "install") as install,
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                bootstrap.main([*self.arguments(), "--apply"])
        install.assert_not_called()

    def test_apply_builds_before_install(self):
        actions = []

        def nix(*args, **kwargs):
            actions.append(args[0])
            return self.fake_nix(*args, **kwargs)

        with (
            mock.patch.object(
                bootstrap.pwd,
                "getpwnam",
                return_value=SimpleNamespace(pw_uid=1000, pw_dir="/home/tester"),
            ),
            mock.patch.object(bootstrap, "nix", side_effect=nix),
            mock.patch.object(bootstrap, "check_destination"),
            mock.patch.object(
                bootstrap,
                "install",
                side_effect=lambda *args: actions.append("install"),
            ),
        ):
            bootstrap.main([*self.arguments(), "--apply"])
        self.assertEqual(actions, ["eval", "flake", "build", "install"])

    def test_install_backs_up_first_and_publishes_entry_point_last(self):
        destination = self.root / "target"
        destination.mkdir()
        with (
            mock.patch.object(bootstrap, "privileged") as privileged,
            mock.patch.object(
                bootstrap.shutil, "which", side_effect=lambda name: "/test-bin/" + name
            ),
        ):
            bootstrap.install(self.root, destination, self.host)
        calls = [call.args for call in privileged.call_args_list]
        self.assertEqual(Path(calls[0][0]).name, "cp")
        copies = [call for call in calls if Path(call[0]).name == "install"]
        self.assertEqual(Path(copies[-1][-1]).name, "flake.nix")
        self.assertEqual(len(copies), len(bootstrap.FILES))
        self.assertEqual(calls[-1][-2:], ("set-timeout", ""))

    def test_install_files_and_repeat_run_preserve_original_configuration(self):
        destination = self.root / "etc-nixos"
        destination.mkdir()
        original = destination / "configuration.nix"
        original.write_text("original configuration")
        stage = self.root / "stage"
        stage.mkdir()
        bootstrap.write_configuration(stage, ROOT, self.hardware, self.host)
        (stage / "flake.lock").write_text("{}")

        def dispatch(command, *arguments):
            name = Path(command).name
            if name == "cp":
                shutil.copytree(arguments[-2], arguments[-1], symlinks=True)
            elif name == "install":
                shutil.copyfile(arguments[-2], arguments[-1])
            elif name not in ("nixos-rebuild", "bootctl"):
                self.fail(f"Unexpected command: {name}")

        with (
            mock.patch.object(bootstrap, "privileged", side_effect=dispatch),
            mock.patch.object(
                bootstrap.shutil, "which", side_effect=lambda name: "/test-bin/" + name
            ),
        ):
            bootstrap.install(stage, destination, self.host)
            bootstrap.install(stage, destination, self.host)
        self.assertEqual(original.read_text(), "original configuration")
        self.assertEqual(
            (destination / "project-hardware.nix").read_bytes(),
            self.hardware.read_bytes(),
        )
        backups = list(self.root.glob("etc-nixos.pre-project-*"))
        self.assertEqual(len(backups), 2)
        self.assertTrue(
            all(
                (backup / "configuration.nix").read_text() == "original configuration"
                for backup in backups
            )
        )


if __name__ == "__main__":
    unittest.main()
