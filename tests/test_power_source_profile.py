import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "power_source_profile", Path(__file__).resolve().parents[1] / "scripts/power-source-profile.py"
)
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)
PROFILES = ["power-saver", "balanced", "performance"]


class PowerPolicyTests(unittest.TestCase):
    def setUp(self):
        self.policy = module.PowerPolicy()

    def choose(self, on_battery, percentage, active="balanced", profiles=PROFILES):
        return self.policy.choose(on_battery, percentage, profiles, active)

    def test_initial_source_and_threshold(self):
        self.assertEqual(self.choose(False, 10), "performance")
        self.assertIsNone(self.choose(True, 21))
        self.assertEqual(self.choose(True, 20), "power-saver")
        self.assertEqual(self.choose(True, 19), "power-saver")

    def test_manual_choice_survives_battery_events_until_source_changes(self):
        self.choose(True, 50)
        self.policy.profile_changed("performance")
        self.assertIsNone(self.choose(True, 40, "performance"))
        self.assertIsNone(self.choose(True, 20, "performance"))
        self.assertIsNone(self.choose(False, 20, "performance"))
        self.assertFalse(self.policy.manual)
        self.assertEqual(self.choose(True, 20, "performance"), "power-saver")

    def test_automatic_change_is_not_a_manual_override(self):
        self.assertEqual(self.choose(False, 50), "performance")
        self.policy.profile_changed("performance")
        self.assertFalse(self.policy.manual)
        self.assertEqual(self.choose(True, 50, "performance"), "balanced")
        self.policy.profile_changed("balanced")
        self.assertEqual(self.choose(True, 20), "power-saver")

    def test_unplug_clears_ac_override(self):
        self.choose(False, 60)
        self.policy.profile_changed("power-saver")
        self.assertIsNone(self.choose(False, 65, "power-saver"))
        self.assertEqual(self.choose(True, 65, "power-saver"), "balanced")

    def test_no_performance_and_no_battery(self):
        self.assertIsNone(self.choose(False, None, profiles=PROFILES[:2]))
        self.assertEqual(self.choose(False, None), "performance")
        self.assertEqual(self.choose(True, None, "power-saver"), "balanced")

    def test_no_redundant_profile_writes(self):
        self.assertIsNone(self.choose(True, 20, "power-saver"))
        self.assertIsNone(self.choose(False, 50, "performance"))


class BacklightDimmerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.device = self.root / "backlights" / "panel"
        self.device.mkdir(parents=True)
        (self.device / "max_brightness").write_text("10000")
        self.brightness = self.device / "brightness"
        self.brightness.write_text("625")  # 50% using the keyboard's fourth-root curve.
        self.state_file = self.root / "brightness.json"
        self.dimmer = module.BacklightDimmer(self.state_file, self.device.parent)

    def test_cap_and_restore(self):
        self.dimmer.reconcile(True)
        self.assertEqual(int(self.brightness.read_text()), 81)  # 30% on the same curve.
        self.dimmer.reconcile(False)
        self.assertEqual(int(self.brightness.read_text()), 625)

    def test_does_not_brighten_an_already_dim_screen(self):
        self.brightness.write_text("16")
        self.dimmer.reconcile(True)
        self.assertEqual(int(self.brightness.read_text()), 16)
        self.dimmer.reconcile(False)
        self.assertEqual(int(self.brightness.read_text()), 16)

    def test_manual_adjustment_is_not_repeatedly_dimmed_or_restored(self):
        self.dimmer.reconcile(True)
        self.brightness.write_text("256")
        self.dimmer.reconcile(True)
        self.assertEqual(int(self.brightness.read_text()), 256)
        self.dimmer.reconcile(False)
        self.assertEqual(int(self.brightness.read_text()), 256)
        self.dimmer.reconcile(True)
        self.assertEqual(int(self.brightness.read_text()), 81)

    def test_restart_preserves_original_and_does_not_redim(self):
        self.dimmer.reconcile(True)
        restarted = module.BacklightDimmer(self.state_file, self.device.parent)
        restarted.reconcile(True)
        restarted.reconcile(False)
        self.assertEqual(int(self.brightness.read_text()), 625)

    def test_removed_device_and_no_backlight(self):
        self.dimmer.reconcile(True)
        self.brightness.unlink()
        (self.device / "max_brightness").unlink()
        self.device.rmdir()
        self.device.parent.rmdir()
        self.dimmer.reconcile(False)
        self.dimmer.reconcile(True)
        self.assertEqual(self.dimmer.state["devices"], {})


if __name__ == "__main__":
    unittest.main()
