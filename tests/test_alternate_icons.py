"""Ensure the compiled app can actually switch between all ten icons."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ["Default", "Blue", "Purple", "Green", "Mono", "Glass", "Orbit", "Gradient", "Carbon", "Board"]


class IconRegistrationTests(unittest.TestCase):
    def test_generator_emits_all_assets_and_preview_files(self):
        source = (ROOT / "scripts/generate_app_icons.swift").read_text()
        for name in EXPECTED:
            self.assertIn(f'name: "{name}"', source)
        self.assertIn('.appiconset', source)
        self.assertIn('IconPreview-', source)
        self.assertIn('"1024x1024"', source)

    def test_archive_verifies_actual_alternate_icon_entries(self):
        workflow = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertIn("swift scripts/generate_app_icons.swift", workflow)
        self.assertIn('CFBundleIcons:CFBundleAlternateIcons:$icon', workflow)
        self.assertIn('CFBundleAlternateIcons', workflow)

    def test_ios_api_and_preview_use_actual_icon(self):
        ui = (ROOT / "GetMoreRam/SettingsView.swift").read_text()
        self.assertIn("setAlternateIconName(", ui)
        self.assertIn("supportsAlternateIcons", ui)
        self.assertIn("UIApplication.shared.alternateIconName", ui)
        self.assertIn('Image("IconPreview-"', ui)

    def test_release_version_incremented(self):
        pbx = (ROOT / "GetMoreRam.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(pbx.count("CURRENT_PROJECT_VERSION = 3;"), 2)
        self.assertEqual(pbx.count("MARKETING_VERSION = 1.2;"), 2)


if __name__ == "__main__":
    unittest.main()
