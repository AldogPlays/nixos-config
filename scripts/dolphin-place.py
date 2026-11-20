#!/usr/bin/env python3
"""Add one Dolphin Place without replacing existing bookmarks."""

import argparse
import os
from pathlib import Path
import shutil
import tempfile
import xml.etree.ElementTree as ET


BOOKMARK = "http://www.freedesktop.org/standards/desktop-bookmarks"
ET.register_namespace("bookmark", BOOKMARK)


def add_place(filename, directory, title):
    filename = Path(filename)
    uri = Path(directory).absolute().as_uri()
    if filename.exists():
        parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
        tree = ET.parse(filename, parser=parser)
        root = tree.getroot()
        if root.tag != "xbel":
            raise ValueError("Dolphin Places file is not XBEL")
    else:
        root = ET.Element("xbel")
        tree = ET.ElementTree(root)
    if any(item.get("href") == uri for item in root.findall("bookmark")):
        return
    item = ET.SubElement(root, "bookmark", href=uri)
    ET.SubElement(item, "title").text = title
    info = ET.SubElement(item, "info")
    metadata = ET.SubElement(info, "metadata", owner="http://freedesktop.org")
    ET.SubElement(metadata, f"{{{BOOKMARK}}}icon", name="folder-pictures")
    metadata = ET.SubElement(info, "metadata", owner="http://www.kde.org")
    ET.SubElement(metadata, "isSystemItem").text = "false"
    ET.SubElement(metadata, "IsHidden").text = "false"
    filename.parent.mkdir(parents=True, exist_ok=True)
    backup = filename.with_name(filename.name + ".before-waydroid")
    if filename.exists() and not backup.exists():
        shutil.copy2(filename, backup)
    with tempfile.NamedTemporaryFile(dir=filename.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            tree.write(output, encoding="utf-8", xml_declaration=True)
            output.flush()
            os.fsync(output.fileno())
            os.replace(temporary, filename)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("filename")
    parser.add_argument("directory")
    parser.add_argument("title")
    args = parser.parse_args()
    add_place(args.filename, args.directory, args.title)
