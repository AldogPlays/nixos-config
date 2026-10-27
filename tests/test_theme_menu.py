"""Theme selection, cancellation and rebuild failure handling without host writes."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "theme_menu", Path(__file__).parents[1] / "scripts/theme-menu.py"
)
menu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(menu)


class ThemeMenuTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "flake.nix").write_text("{}")
        (self.root / "theme").mkdir()
        self.selection = self.root / "theme/selection.nix"
        self.original = b'{\n  preset = "latte"; # keep this comment\n  wallpaperMode = "color";\n}\n'
        self.selection.write_bytes(self.original)
        self.active = self.root / "active.json"
        self.active.write_text('{"preset":"latte"}')
        self.config = {
            "configuration": {"kind": "checkout", "directory": str(self.root)},
            "defaultSelection": {"preset": "latte", "wallpaperMode": "theme"},
            "presets": {
                "latte": {"name": "Latte"},
                "monochrome": {"name": "Monochrome"},
            },
        }
        self.config_file = self.root / "menu.json"
        self.config_file.write_text(json.dumps(self.config))
        self.calls = []

    def fake_command(self, *arguments, **kwargs):
        args = list(map(str, arguments))
        self.calls.append(args)
        if args[0] == "/run/wrappers/bin/sudo":
            if args[1] == "nixos-rebuild":
                self.active.write_text('{"preset":"monochrome"}')
            elif args[1] == "install":
                shutil.copyfile(args[-2], args[-1])
            elif args[1] == "mv":
                Path(args[-2]).replace(args[-1])
            elif args[1] == "rm":
                Path(args[-1]).unlink(missing_ok=True)
        return SimpleNamespace(returncode=0)

    def apply(self, command=None):
        with contextlib.redirect_stdout(io.StringIO()):
            menu.apply_theme(
                self.config, "monochrome", command or self.fake_command, self.active
            )

    def test_marks_running_theme_instead_of_an_unapplied_selection(self):
        self.selection.write_text('{ preset = "monochrome"; }')
        entries = menu.menu_entries(
            self.config["presets"], menu.active_preset(self.active)
        )
        self.assertIn("Active", entries[0][1])
        self.assertNotIn("Active", entries[1][1])
        self.assertIsNone(menu.active_preset(self.root / "missing"))

    def test_cancel_and_active_choice_never_launch_terminal_or_write(self):
        for choice in [
            SimpleNamespace(returncode=1, stdout="", stderr=""),
            SimpleNamespace(returncode=0, stdout="0\n", stderr=""),
        ]:
            with (
                self.subTest(choice=choice.returncode),
                mock.patch.object(menu, "active_preset", return_value="latte"),
                mock.patch.object(menu.subprocess, "run", return_value=choice) as run,
            ):
                self.assertEqual(menu.main(["--config", str(self.config_file)]), 0)
                self.assertEqual(run.call_count, 1)
            self.assertEqual(self.selection.read_bytes(), self.original)

    def test_new_choice_launches_terminal_without_mutating_configuration(self):
        with (
            mock.patch.object(menu, "active_preset", return_value="latte"),
            mock.patch.object(
                menu.subprocess,
                "run",
                return_value=SimpleNamespace(returncode=0, stdout="1\n", stderr=""),
            ) as run,
        ):
            self.assertEqual(menu.main(["--config", str(self.config_file)]), 0)
        terminal = run.call_args_list[1].args[0]
        self.assertEqual(terminal[0], "alacritty")
        self.assertEqual(terminal[-2:], ["--apply", "monochrome"])
        self.assertEqual(self.selection.read_bytes(), self.original)

    def test_success_builds_before_activation_and_preserves_other_settings(self):
        self.apply()
        self.assertEqual(
            self.selection.read_bytes(),
            self.original.replace(b'"latte"', b'"monochrome"'),
        )
        self.assertEqual(self.calls[0][0], "nix")
        self.assertIn(
            str(self.root) + "#nixosConfigurations.nixos.config.system.build.toplevel",
            self.calls[0],
        )
        self.assertEqual(
            self.calls[1],
            [
                "/run/wrappers/bin/sudo",
                "nixos-rebuild",
                "switch",
                "--flake",
                str(self.root) + "#nixos",
            ],
        )

    def test_build_failure_restores_exact_selection_and_never_activates(self):
        def fail(*arguments, **kwargs):
            self.assertEqual(arguments[0], "nix")
            raise subprocess.CalledProcessError(1, arguments)

        with self.assertRaises(subprocess.CalledProcessError):
            self.apply(fail)
        self.assertEqual(self.selection.read_bytes(), self.original)
        self.assertEqual(menu.active_preset(self.active), "latte")

    def test_cancelled_authentication_restores_selection(self):
        def fail(*arguments, **kwargs):
            if arguments[0] == "/run/wrappers/bin/sudo":
                raise subprocess.CalledProcessError(1, arguments)

        with self.assertRaises(subprocess.CalledProcessError):
            self.apply(fail)
        self.assertEqual(self.selection.read_bytes(), self.original)

    def test_partial_activation_does_not_revert_source_behind_active_system(self):
        def partial(*arguments, **kwargs):
            if arguments[0] == "/run/wrappers/bin/sudo":
                self.active.write_text('{"preset":"monochrome"}')
                raise subprocess.CalledProcessError(1, arguments)

        with self.assertRaises(subprocess.CalledProcessError):
            self.apply(partial)
        self.assertIn(b'"monochrome"', self.selection.read_bytes())

    def test_concurrent_edit_is_preserved_and_activation_is_cancelled(self):
        def edit(*arguments, **kwargs):
            self.assertEqual(arguments[0], "nix")
            self.selection.write_text("# another edit\n")

        with self.assertRaisesRegex(RuntimeError, "activation cancelled"):
            self.apply(edit)
        self.assertEqual(self.selection.read_text(), "# another edit\n")

    def test_unknown_preset_and_ambiguous_settings_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unknown theme"):
            menu.apply_theme(self.config, "unlisted", self.fake_command, self.active)
        self.selection.write_text('{ preset = "latte"; }')
        with self.assertRaisesRegex(ValueError, "literal preset"):
            self.apply()
        self.assertFalse(self.calls)

    def test_portable_host_preserves_hardware_and_wallpaper_preferences(self):
        self.config["configuration"]["kind"] = "portable"
        host = self.root / "project-host.json"
        original = {
            "bootstrapSchema": 1,
            "username": "alex",
            "disk": "destination-disk",
            "themeSelection": {"preset": "latte", "wallpaperMode": "color"},
        }
        host.write_text(json.dumps(original))
        self.apply()
        expected = {
            **original,
            "themeSelection": {"preset": "monochrome", "wallpaperMode": "color"},
        }
        self.assertEqual(json.loads(host.read_text()), expected)
        self.assertEqual(self.selection.read_bytes(), self.original)
        self.assertEqual(self.calls[0][1], "install")

    def test_second_apply_cannot_start_while_another_switch_holds_lock(self):
        with (
            mock.patch.object(menu.os, "geteuid", return_value=1000),
            mock.patch.dict(menu.os.environ, {"XDG_RUNTIME_DIR": str(self.root)}),
            mock.patch.object(menu.fcntl, "flock", side_effect=BlockingIOError),
            mock.patch.object(menu.sys.stdin, "isatty", return_value=False),
            mock.patch.object(menu, "apply_theme") as apply,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(
                menu.main(["--config", str(self.config_file), "--apply", "monochrome"]),
                1,
            )
        apply.assert_not_called()

    def test_running_apply_as_root_is_rejected_before_writes(self):
        with (
            mock.patch.object(menu.os, "geteuid", return_value=0),
            mock.patch.object(menu, "apply_theme") as apply,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            self.assertEqual(
                menu.main(["--config", str(self.config_file), "--apply", "monochrome"]),
                1,
            )
        apply.assert_not_called()
        self.assertEqual(self.selection.read_bytes(), self.original)


if __name__ == "__main__":
    unittest.main()
