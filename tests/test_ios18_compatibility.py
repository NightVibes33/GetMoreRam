"""Guard against accidentally raising GetMoreRam's minimum iOS version."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "GetMoreRam.xcodeproj" / "project.pbxproj"
WORKFLOW = ROOT / ".github" / "workflows" / "build.yml"
README = ROOT / "README.md"


class IOS18Through27Tests(unittest.TestCase):
    def test_both_app_configs_and_project_config_have_ios18_target(self):
        settings = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+);", PROJECT.read_text())
        self.assertEqual(len(settings), 4)
        self.assertEqual(set(settings), {"18.0"})

    def test_archive_checks_ios18_minimum_and_unsigned_ipa(self):
        wf = WORKFLOW.read_text()
        self.assertIn('[[ "$minimum" == "18.0" ]]', wf)
        self.assertIn('[[ "$sdk" == 27* ]]', wf)
        self.assertIn('GetMoreRam-unsigned-iOS18-27.ipa', wf)
        self.assertIn('CODE_SIGNING_ALLOWED=NO', wf)
        self.assertNotIn('GetMoreRam-unsigned-iOS27.ipa', wf)

    def test_documented_side_store_resign_flow(self):
        doc = README.read_text()
        self.assertIn('minimum OS: **iOS 18.0**', doc)
        self.assertIn('Re-sign and reinstall/refresh', doc)
        self.assertIn('App IDs', doc)


if __name__ == "__main__":
    unittest.main()
