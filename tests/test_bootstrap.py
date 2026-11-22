"""Bootstrap planning and failure handling; never modify the installed system."""

import copy
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
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
    def test_packet_tracer_missing_skips_without_import(self):
        with mock.patch.object(bootstrap, "nix") as nix, mock.patch.object(bootstrap, "run") as run:
            self.assertFalse(bootstrap.prepare_packet_tracer(
                self.root / "store-installer", "installer.deb", "sha256-pinned", self.root))
        nix.assert_not_called()
        run.assert_not_called()

    def test_packet_tracer_in_store_needs_no_download(self):
        source = self.root / "store-installer"
        source.write_text("cached")
        with mock.patch.object(bootstrap, "nix") as nix, mock.patch.object(bootstrap, "run") as run:
            self.assertTrue(bootstrap.prepare_packet_tracer(
                source, "installer.deb", "sha256-pinned", self.root))
        nix.assert_not_called()
        run.assert_not_called()

    def test_packet_tracer_download_is_verified_before_import(self):
        installer = self.root / "Downloads/installer.deb"
        installer.parent.mkdir()
        installer.write_text("download")
        for actual_hash, enabled in (("sha256-pinned", True), ("sha256-wrong", False)):
            with (
                self.subTest(actual_hash=actual_hash),
                mock.patch.object(bootstrap, "nix", return_value=SimpleNamespace(stdout=actual_hash + "\n")) as nix,
                mock.patch.object(bootstrap, "run") as run,
                contextlib.redirect_stderr(io.StringIO()),
            ):
                self.assertEqual(bootstrap.prepare_packet_tracer(
                    self.root / "store-installer", "installer.deb", "sha256-pinned", self.root), enabled)
                nix.assert_called_once_with("hash", "file", "--type", "sha256", installer,
                                            capture_output=True, text=True)
                if enabled:
                    run.assert_called_once_with(["nix-store", "--add-fixed", "sha256", str(installer)],
                                                stdout=subprocess.DEVNULL)
                else:
                    run.assert_not_called()

    def test_generated_host_theme_selection_survives_bootstrap_rerun(self):
        with tempfile.TemporaryDirectory() as raw:
            directory = Path(raw)
            selection = {"preset": "monochrome", "wallpaperMode": "color"}
            (directory / "project-host.json").write_text(json.dumps({
                "bootstrapSchema": 1, "themeSelection": selection, "ignored": "private"
            }))
            host = {"username": "tester"}
            bootstrap.preserve_theme_selection(directory / "configuration.nix", host)
            self.assertEqual(host, {"username": "tester", "themeSelection": selection})
            (directory / "project-host.json").write_text('{"bootstrapSchema":2,"themeSelection":{}}')
            host = {"username": "tester"}
            bootstrap.preserve_theme_selection(directory / "configuration.nix", host)
            self.assertEqual(host, {"username": "tester"})

    def setUp(self):
        # Activation is mocked; these host tools need not exist in the build sandbox.
        real_which = bootstrap.shutil.which
        host_tools = mock.patch.object(
            bootstrap.shutil,
            "which",
            side_effect=lambda name: name if name in ("nixos-rebuild", "bootctl") else real_which(name),
        )
        host_tools.start()
        self.addCleanup(host_tools.stop)
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
        self.assertFalse(json.loads((output / "project-host.json").read_text())["packetTracerEnable"])
        self.assertIn("packetTracerEnable = host.packetTracerEnable or false;",
                      (output / "flake.nix").read_text())
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
                side_effect=lambda stage, destination, host: actions.append(
                    "install-with-packet-tracer" if host["packetTracerEnable"] else "install"
                ),
            ),
        ):
            bootstrap.main([*self.arguments(), "--apply"])
        self.assertEqual(actions, ["eval", "flake", "build", "install"])

    def test_install_prepares_complete_copy_before_atomic_publication(self):
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
        self.assertEqual(len(copies), len(bootstrap.FILES))
        backup = Path(calls[0][-1])
        self.assertTrue(all(Path(call[-1]).parent == backup for call in copies))
        exchange = next(call for call in calls if Path(call[0]).name == "mv")
        self.assertEqual(
            exchange[1:], ("--exchange", "--no-copy", "-T", "--", backup, destination)
        )
        self.assertLess(calls.index(copies[-1]), calls.index(exchange))
        rebuild = next(call for call in calls if Path(call[0]).name == "nixos-rebuild")
        self.assertLess(calls.index(exchange), calls.index(rebuild))
        self.assertEqual(calls[-1][-2:], ("set-timeout", ""))

    def install_fixture(self):
        destination = self.root / "etc-nixos"
        destination.mkdir()
        original = destination / "configuration.nix"
        original.write_text("original configuration")
        original.chmod(0o640)
        (destination / "private").mkdir(mode=0o700)
        (destination / "private/note").write_text("unrelated local configuration")
        (destination / "linked.nix").symlink_to("configuration.nix")
        stage = self.root / "stage"
        stage.mkdir()
        bootstrap.write_configuration(stage, ROOT, self.hardware, self.host)
        (stage / "flake.lock").write_text("{}")
        return stage, destination

    def filesystem_command(self, command, *arguments):
        name = Path(command).name
        if name in ("cp", "install", "mv"):
            # Exercise real coreutils, including the filesystem's atomic exchange.
            subprocess.run([name, *map(str, arguments)], check=True)
        elif name not in ("nixos-rebuild", "bootctl"):
            self.fail(f"Unexpected command: {name}")

    def directory_snapshot(self, directory):
        snapshot = {}
        for path in directory.rglob("*"):
            content = None
            if path.is_symlink():
                content = str(path.readlink())
            elif path.is_file():
                content = path.read_bytes()
            snapshot[str(path.relative_to(directory))] = (path.lstat().st_mode, content)
        return snapshot

    def test_install_files_and_repeat_run_preserve_original_configuration(self):
        stage, destination = self.install_fixture()
        original = self.directory_snapshot(destination)
        with mock.patch.object(bootstrap, "privileged", side_effect=self.filesystem_command):
            bootstrap.install(stage, destination, self.host)
            first = self.directory_snapshot(destination)
            host = json.loads((stage / "project-host.json").read_text())
            host["themeSelection"] = {"preset": "latte", "wallpaperMode": "color"}
            (stage / "project-host.json").write_text(json.dumps(host))
            bootstrap.install(stage, destination, self.host)
        current = self.directory_snapshot(destination)
        self.assertEqual({name: current[name] for name in original}, original)
        self.assertEqual(
            (destination / "project-hardware.nix").read_bytes(),
            self.hardware.read_bytes(),
        )
        self.assertEqual(json.loads((destination / "project-host.json").read_text()), host)
        backups = sorted(self.root.glob("etc-nixos.pre-project-*"))
        self.assertEqual(len(backups), 2)
        self.assertEqual(self.directory_snapshot(backups[0]), original)
        self.assertEqual(self.directory_snapshot(backups[1]), first)

    def test_failed_preparation_or_exchange_leaves_existing_host_intact(self):
        stage, destination = self.install_fixture()
        # A repeat installation must never expose mixed old/new generated files.
        for name in bootstrap.FILES:
            (destination / name).write_text(
                '{"bootstrapSchema": 1}' if name == "project-host.json" else "old " + name
            )
        original = self.directory_snapshot(destination)
        for failure in ("cp", *bootstrap.FILES, "mv"):
            with self.subTest(failure=failure):
                commands = []

                def dispatch(command, *arguments):
                    name = Path(command).name
                    commands.append(name)
                    if name == failure or (
                        name == "install" and Path(arguments[-1]).name == failure
                    ):
                        raise subprocess.CalledProcessError(1, [name])
                    self.filesystem_command(command, *arguments)

                stderr = io.StringIO()
                with (
                    mock.patch.object(bootstrap, "privileged", side_effect=dispatch),
                    contextlib.redirect_stderr(stderr),
                ):
                    with self.assertRaises(subprocess.CalledProcessError):
                        bootstrap.install(stage, destination, self.host)
                self.assertEqual(self.directory_snapshot(destination), original)
                self.assertNotIn("nixos-rebuild", commands)
                self.assertIn("no activation was attempted", stderr.getvalue())

    def test_interruption_after_exchange_retains_both_complete_configurations(self):
        stage, destination = self.install_fixture()
        original = self.directory_snapshot(destination)

        def dispatch(command, *arguments):
            self.filesystem_command(command, *arguments)
            if Path(command).name == "mv":
                raise KeyboardInterrupt

        with (
            mock.patch.object(bootstrap, "privileged", side_effect=dispatch),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            with self.assertRaises(KeyboardInterrupt):
                bootstrap.install(stage, destination, self.host)
        backups = list(self.root.glob("etc-nixos.pre-project-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(self.directory_snapshot(backups[0]), original)
        for name in bootstrap.FILES:
            self.assertEqual((destination / name).read_bytes(), (stage / name).read_bytes())

    def test_activation_failure_keeps_backup_and_complete_replacement(self):
        stage, destination = self.install_fixture()
        original = self.directory_snapshot(destination)
        commands = []

        def dispatch(command, *arguments):
            name = Path(command).name
            commands.append(name)
            if name == "nixos-rebuild":
                raise subprocess.CalledProcessError(1, [name])
            self.filesystem_command(command, *arguments)

        stderr = io.StringIO()
        with (
            mock.patch.object(bootstrap, "privileged", side_effect=dispatch),
            contextlib.redirect_stderr(stderr),
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                bootstrap.install(stage, destination, self.host)
        backup = next(self.root.glob("etc-nixos.pre-project-*"))
        self.assertEqual(self.directory_snapshot(backup), original)
        for name in bootstrap.FILES:
            self.assertEqual((destination / name).read_bytes(), (stage / name).read_bytes())
        self.assertIn("Activation failed", stderr.getvalue())
        self.assertNotIn("bootctl", commands)

    def test_efi_timeout_failure_does_not_misreport_successful_activation(self):
        stage, destination = self.install_fixture()
        commands = []

        def dispatch(command, *arguments):
            name = Path(command).name
            commands.append(name)
            if name == "bootctl":
                raise subprocess.CalledProcessError(1, [name])
            self.filesystem_command(command, *arguments)

        stderr = io.StringIO()
        with (
            mock.patch.object(bootstrap, "privileged", side_effect=dispatch),
            contextlib.redirect_stderr(stderr),
        ):
            bootstrap.install(stage, destination, self.host)
        self.assertIn("nixos-rebuild", commands)
        self.assertIn("Configuration activated", stderr.getvalue())
        self.assertNotIn("Activation failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
