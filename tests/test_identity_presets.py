"""Android identity preset sends genuinely Android headers, without changing Windows."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = (ROOT / "GetMoreRam/SettingsView.swift").read_text()
LOGIN = (ROOT / "GetMoreRam/SideStoreAuthentication.swift").read_text()
REMOTE = (ROOT / "GetMoreRam/AnisetteDataHelper.swift").read_text()
ODA = (ROOT / "GetMoreRam/OnDeviceAnisetteHelper.swift").read_text()

class IdentityPresetsTests(unittest.TestCase):
    def test_android_uses_android_user_agent_not_mac(self):
        self.assertIn('private let androidUserAgent = "AuthKit/1 (Android; Android 14) (com.apple.akd/1.0)"', SETTINGS)
        self.assertIn('case "Android":\n                        customClientInfo = androidInfo\n                        customUserAgent = androidUserAgent', SETTINGS)
        self.assertIn('private let androidInfo = "<Pixel 7> <Android;14;', SETTINGS)
        self.assertIn('$0.userAgent = "AuthKit/1 (Android; Android 14) (com.apple.akd/1.0)"', ODA)

    def test_legacy_android_mac_user_agent_migrates_without_overwriting_custom(self):
        self.assertIn('migrateLegacyAndroidPreset()', SETTINGS)
        self.assertIn('guard identityPreset == "Android",', SETTINGS)
        self.assertIn('customClientInfo == androidInfo,', SETTINGS)
        self.assertIn('customUserAgent == "AuthKit/1 (Macintosh; OS X 26.6)', SETTINGS)
        self.assertIn('customUserAgent = androidUserAgent', SETTINGS)

    def test_windows_preset_is_untouched_and_headers_consumed(self):
        self.assertIn('case "Windows":\n                        customClientInfo = windowsInfo\n                        customUserAgent = "AuthKit/1 (Windows; 10.0) (com.apple.akd/1.0)"', SETTINGS)
        self.assertIn('headers.grandSlam.userAgent = effectiveAgent', LOGIN)
        self.assertIn('userAgent: effectiveAgent', LOGIN)
        self.assertIn('defaults.string(forKey: "CustomUserAgent")', REMOTE)

if __name__ == "__main__":
    unittest.main()
