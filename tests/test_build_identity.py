"""Prevent release confusion when SideStore refreshes an older installed IPA."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class BuildIdentityTests(unittest.TestCase):
    def test_release_incremented_in_both_configs(self):
        project = (ROOT / "GetMoreRam.xcodeproj" / "project.pbxproj").read_text()
        self.assertEqual(len(re.findall(r"CURRENT_PROJECT_VERSION = 3;", project)), 2)
        self.assertEqual(len(re.findall(r"MARKETING_VERSION = 1\.2;", project)), 2)
        self.assertNotIn("CURRENT_PROJECT_VERSION = 1;", project)

    def test_settings_shows_installed_version_and_oda_mode(self):
        ui = (ROOT / "GetMoreRam" / "SettingsView.swift").read_text()
        self.assertIn('LabeledContent("App Version", value: appVersionLabel)', ui)
        self.assertIn('LabeledContent("Anisette Mode"', ui)
        self.assertIn('Toggle("On-device Anisette"', ui)
        self.assertIn('"CFBundleShortVersionString"', ui)
        self.assertIn('"CFBundleVersion"', ui)

    def test_documents_side_store_ipa_update(self):
        doc = (ROOT / "README.md").read_text()
        self.assertIn("v1.1 (build 2)", doc)
        self.assertIn("not just Refresh", doc)

if __name__ == "__main__":
    unittest.main()
