"""Select a power profile from UPower events; leave manual choices alone."""

import logging
import sys
from dataclasses import dataclass


@dataclass
class PowerPolicy:
    low_battery: float = 20
    source: bool | None = None
    expected: str | None = None
    manual: bool = False

    def profile_changed(self, profile):
        if self.expected is not None and profile != self.expected:
            self.manual = True

    def choose(self, on_battery, percentage, available, active):
        if self.source != on_battery:
            self.manual = False
        self.source = on_battery
        if self.manual:
            return None
        if not on_battery:
            wanted = "performance"
        elif percentage is not None and percentage <= self.low_battery:
            wanted = "power-saver"
        else:
            wanted = "balanced"
        # Some portable hosts do not expose a performance profile.
        if wanted not in available:
            wanted = "balanced" if "balanced" in available else active
        self.expected = wanted
        return wanted if wanted != active else None


def main():
    from gi.repository import Gio, GLib

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    loop = GLib.MainLoop()
    policy = PowerPolicy()
    upower_name = "org.freedesktop.UPower"
    upower_path = "/org/freedesktop/UPower"
    profiles_name = "org.freedesktop.UPower.PowerProfiles"
    profiles_path = "/org/freedesktop/UPower/PowerProfiles"
    failed = False

    def proxy(name, path, interface):
        result = Gio.DBusProxy.new_sync(
            bus, Gio.DBusProxyFlags.GET_INVALIDATED_PROPERTIES,
            None, name, path, interface, None,
        )
        if not result.get_name_owner():
            raise RuntimeError(f"{name} is unavailable")
        return result

    upower = proxy(upower_name, upower_path, upower_name)
    battery = proxy(upower_name, upower_path + "/devices/DisplayDevice", upower_name + ".Device")
    profiles = proxy(profiles_name, profiles_path, profiles_name)

    def value(service, name):
        prop = service.get_cached_property(name)
        if prop is None:
            raise RuntimeError(f"Missing {name} on {service.get_object_path()}")
        return prop.unpack()

    def reconcile():
        available = [entry["Profile"] for entry in value(profiles, "Profiles")]
        percentage = value(battery, "Percentage") if value(battery, "IsPresent") else None
        wanted = policy.choose(
            value(upower, "OnBattery"), percentage,
            available, value(profiles, "ActiveProfile"),
        )
        if wanted is not None:
            bus.call_sync(
                profiles_name, profiles_path, "org.freedesktop.DBus.Properties", "Set",
                GLib.Variant("(ssv)", (profiles_name, "ActiveProfile", GLib.Variant("s", wanted))),
                None, Gio.DBusCallFlags.NONE, 5000, None,
            )
            logging.info("Automatic profile: %s", wanted)

    def changed(service, properties, _invalidated):
        nonlocal failed
        try:
            updates = properties.unpack()
            if service == profiles and "ActiveProfile" in updates:
                policy.profile_changed(updates["ActiveProfile"])
                if policy.manual:
                    logging.info("Manual profile: %s (until power source changes)", updates["ActiveProfile"])
            reconcile()
        except Exception:
            logging.exception("Unable to update power profile")
            failed = True
            loop.quit()

    def owner_changed(service, _property):
        nonlocal failed
        if not service.get_name_owner():
            logging.error("Power service disconnected; restarting policy")
            failed = True
            loop.quit()

    for service in (upower, battery, profiles):
        service.connect("g-properties-changed", changed)
        service.connect("notify::g-name-owner", owner_changed)
    reconcile()
    loop.run()
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
