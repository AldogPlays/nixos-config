import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "battery_charge", Path(__file__).resolve().parents[1] / "scripts/battery-charge.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BatteryChargeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def supply(self, name="BAT7", kind="Battery", modes="[Fast] Standard Long_Life"):
        device = self.root / name
        device.mkdir()
        (device / "type").write_text(kind)
        if modes is not None:
            (device / "charge_types").write_text(modes)
        return device / "charge_types"

    def run_action(self, action, uid=0):
        output, errors = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors), mock.patch.object(
            module.os, "geteuid", return_value=uid
        ):
            result = module.main([action], self.root)
        return result, output.getvalue(), errors.getvalue()

    @staticmethod
    def firmware_write(path, value, **_kwargs):
        # Model the kernel's interface: a write changes the bracketed readback.
        modes, _ = module.read_modes(path)
        selected = value.strip()
        if selected not in modes:
            raise OSError("Unsupported mode")
        with path.open("w") as stream:
            stream.write(" ".join(f"[{mode}]" if mode == selected else mode for mode in sorted(modes)))
        return len(value)

    def test_nonstandard_battery_name_and_nonbattery_are_handled(self):
        battery = self.supply()
        ac = self.supply("AC", "Mains")
        with mock.patch.object(Path, "write_text", autospec=True, side_effect=self.firmware_write) as writes:
            result, output, _ = self.run_action("protect")
        self.assertEqual(result, 0)
        self.assertIn("BAT7: Long_Life", output)
        self.assertEqual(writes.call_args_list, [mock.call(battery, "Long_Life\n")])
        self.assertIn("[Fast]", ac.read_text())

    def test_full_uses_standard_instead_of_rapid_charge(self):
        path = self.supply(modes="Fast Standard [Long_Life]")
        with mock.patch.object(Path, "write_text", autospec=True, side_effect=self.firmware_write) as writes:
            result, output, _ = self.run_action("full")
        self.assertEqual(result, 0)
        self.assertIn("normal full charging allowed", output)
        writes.assert_called_once_with(path, "Standard\n")

    def test_already_protected_does_not_write(self):
        self.supply(modes="Fast Standard [Long_Life]")
        with mock.patch.object(Path, "write_text") as writes:
            self.assertEqual(self.run_action("protect")[0], 0)
        writes.assert_not_called()

    def test_unsupported_and_missing_controls_are_skipped_without_writes(self):
        self.supply(modes="[Standard] Fast")
        self.supply("BAT8", modes=None)
        with mock.patch.object(Path, "write_text") as writes:
            result, output, _ = self.run_action("protect")
        self.assertEqual(result, 0)
        self.assertIn("No supported charging-mode controls", output)
        writes.assert_not_called()

    def test_status_requires_no_root_and_does_not_write(self):
        self.supply()
        with mock.patch.object(Path, "write_text") as writes:
            result, output, _ = self.run_action("status", uid=1000)
        self.assertEqual(result, 0)
        self.assertIn("BAT7: Fast", output)
        writes.assert_not_called()

    def test_unprivileged_change_is_rejected(self):
        self.supply()
        with mock.patch.object(Path, "write_text") as writes:
            result, _, errors = self.run_action("full", uid=1000)
        self.assertEqual(result, 1)
        self.assertIn("sudo battery-charge full", errors)
        writes.assert_not_called()

    def test_failed_write_is_not_reported_as_success(self):
        self.supply()
        with mock.patch.object(Path, "write_text", side_effect=PermissionError("write denied")):
            result, output, errors = self.run_action("protect")
        self.assertEqual(result, 1)
        self.assertNotIn("firmware conservation limit", output)
        self.assertIn("write denied", errors)

    def test_firmware_ignoring_request_is_detected(self):
        self.supply()
        with mock.patch.object(Path, "write_text"):
            result, output, errors = self.run_action("protect")
        self.assertEqual(result, 1)
        self.assertNotIn("firmware conservation limit", output)
        self.assertIn("firmware reports Fast", errors)

    def test_ambiguous_readback_is_rejected_before_writing(self):
        self.supply(modes="[Fast] Standard [Long_Life]")
        with mock.patch.object(Path, "write_text") as writes:
            result, _, errors = self.run_action("protect")
        self.assertEqual(result, 1)
        self.assertIn("expected one selected charging mode", errors)
        writes.assert_not_called()

    def test_host_without_batteries_is_a_successful_noop(self):
        result, output, errors = self.run_action("protect")
        self.assertEqual(result, 0)
        self.assertIn("No batteries detected", output)
        self.assertEqual(errors, "")


if __name__ == "__main__":
    unittest.main()
