#!/usr/bin/env python3
"""Hide the recovery Instagram launcher without replacing Waydroid's writable file."""

import configparser
from pathlib import Path
import shutil
import sys


entry = Path(sys.argv[1]) / "waydroid.com.instagram.android.desktop"
if entry.is_file():
    desktop = configparser.ConfigParser(interpolation=None)
    desktop.optionxform = str
    desktop.read(entry)
    if desktop.get("Desktop Entry", "NoDisplay", fallback="false").lower() != "true":
        backup = entry.with_name(entry.name + ".before-instagram-policy")
        if not backup.exists():
            shutil.copy2(entry, backup)
        desktop.set("Desktop Entry", "NoDisplay", "true")
        with entry.open("w") as output:
            desktop.write(output, space_around_delimiters=False)
