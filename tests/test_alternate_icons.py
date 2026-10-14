"""Validate ten *supplied* icon assets instead of generated placeholders."""
from pathlib import Path
import json
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "GetMoreRam" / "Assets.xcassets"
EXPECTED = ("Default", "Blue", "Purple", "Green", "Mono",
            "Glass", "Orbit", "Gradient", "Carbon", "Board")

def dimensions(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", data[16:24])

class IconRegistrationTests(unittest.TestCase):
    def test_all_supplied_app_icons_are_registered_1024_px(self):
        for name in EXPECTED:
            with self.subTest(name=name):
                root = ASSETS / ("AppIcon.appiconset" if name == "Default" else f"{name}.appiconset")
                self.assertEqual(dimensions(root / f"{name}.png"), (1024,1024))
                contents = json.loads((root / "Contents.json").read_text())
                self.assertEqual(contents["images"][0]["filename"], f"{name}.png")
                self.assertEqual(contents["images"][0]["size"], "1024x1024")

    def test_all_preview_images_exist_and_match_sources(self):
        for name in EXPECTED:
            with self.subTest(name=name):
                preview = ASSETS / f"IconPreview-{name}.imageset"
                self.assertEqual(dimensions(preview / f"{name}.png"), (256,256))
                contents = json.loads((preview / "Contents.json").read_text())
                self.assertEqual(contents["images"][0]["filename"], f"{name}.png")

    def test_xcode_uses_committed_assets_without_regenerating_them(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertIn("Verify all ten supplied Xcode icon assets", workflow)
        self.assertNotIn("swift scripts/generate_app_icons.swift", workflow)
        self.assertIn("CFBundleIcons:CFBundleAlternateIcons:$icon", workflow)

    def test_ios_api_preview_and_actual_icon_name(self):
        ui = (ROOT / "GetMoreRam/SettingsView.swift").read_text()
        self.assertIn("setAlternateIconName(", ui)
        self.assertIn("supportsAlternateIcons", ui)
        self.assertIn("UIApplication.shared.alternateIconName", ui)
        self.assertIn('Image("IconPreview-"', ui)

    def test_release_version(self):
        project = (ROOT / "GetMoreRam.xcodeproj" / "project.pbxproj").read_text()
        self.assertEqual(project.count("CURRENT_PROJECT_VERSION = 3;"), 2)
        self.assertEqual(project.count("MARKETING_VERSION = 1.2;"), 2)

if __name__ == "__main__":
    unittest.main()
