#!/usr/bin/env python3
"""Apply menu policy while preserving writable Android and game launchers."""

import configparser
from pathlib import Path
import shutil
import sys


policies = {
    "waydroid.com.instagram.android.desktop": {"NoDisplay": "true"},
    "waydroid.com.aurora.store.desktop": {"NoDisplay": "true"},
    "waydroid.com.instagram.android.piko.desktop": {"GenericName": "Messages and photos"},
    "net.lutris.ea-app-1.desktop": {"GenericName": "EA games"},
}
for filename, settings in policies.items():
    entry = Path(sys.argv[1]) / filename
    if not entry.is_file():
        continue
    desktop = configparser.ConfigParser(interpolation=None)
    desktop.optionxform = str
    desktop.read(entry)
    if any(desktop.get("Desktop Entry", key, fallback="") != value for key, value in settings.items()):
        suffix = (
            ".before-instagram-policy"
            if filename == "waydroid.com.instagram.android.desktop"
            else ".before-launcher-policy"
        )
        backup = entry.with_name(entry.name + suffix)
        if not backup.exists():
            shutil.copy2(entry, backup)
        for key, value in settings.items():
            desktop.set("Desktop Entry", key, value)
        with entry.open("w") as output:
            desktop.write(output, space_around_delimiters=False)
