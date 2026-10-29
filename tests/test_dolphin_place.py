import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET


spec = importlib.util.spec_from_file_location(
    "dolphin_place", Path(__file__).resolve().parents[1] / "scripts/dolphin-place.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class DolphinPlaceTests(unittest.TestCase):
    def test_preserves_existing_bookmarks_and_metadata_and_backs_up(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "places.xbel"
            original = b'''<xbel xmlns:custom="urn:example"><bookmark href="file:///keep"><title>Keep</title><info><custom:data>value</custom:data></info></bookmark></xbel>'''
            path.write_bytes(original)
            module.add_place(path, "/home/alex/Pictures/Instagram", "Instagram Uploads")
            root = ET.parse(path).getroot()
            self.assertEqual(root.find("bookmark/title").text, "Keep")
            self.assertEqual(root.find("bookmark/info/{urn:example}data").text, "value")
            self.assertEqual(path.with_name("places.xbel.before-waydroid").read_bytes(), original)
            result = path.read_bytes()
            module.add_place(path, "/home/alex/Pictures/Instagram", "Instagram Uploads")
            self.assertEqual(path.read_bytes(), result)
            self.assertEqual(len(root.findall("bookmark")), 2)

    def test_invalid_file_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "places.xbel"
            path.write_text("<broken")
            with self.assertRaises(ET.ParseError):
                module.add_place(path, "/photos", "Photos")
            self.assertEqual(path.read_text(), "<broken")
            self.assertFalse(path.with_name("places.xbel.before-waydroid").exists())


if __name__ == "__main__":
    unittest.main()
