"""Pinned StosSign developer API uses the active Client Identity, not Xcode."""
from pathlib import Path
import unittest
from scripts.patch_stossign_identity import patch_source, METHODS

ROOT = Path(__file__).resolve().parents[1]

class DeveloperIdentityPatchTests(unittest.TestCase):
    def test_all_developer_request_dispatchers_use_selected_identity(self):
        fixture = ('"User-Agent": "Xcode",\n'
                   '"X-MMe-Client-Info": session.anisetteData.deviceDescription,\n'
                   '"X-Xcode-Version": "27.0 (27A5218g)",\n') * len(METHODS)
        fixture += '\n    private init() {}\n'
        result = patch_source(fixture)
        self.assertEqual(result.count('"User-Agent": getMoreRamDeveloperUserAgent(),'), 3)
        self.assertEqual(result.count('"X-MMe-Client-Info": getMoreRamDeveloperClientInfo(for: session),'), 3)
        self.assertEqual(result.count('"X-Xcode-Version": "26.0 (26A242)",'), 3)
        self.assertIn('UserDefaults.standard.string(forKey: "CustomUserAgent")', result)
        self.assertIn('UserDefaults.standard.string(forKey: "CustomClientInfo")', result)
        self.assertIn('return session.anisetteData.deviceDescription', result)
        self.assertIn('defaults.bool(forKey: "UseOnDeviceAnisette")', result)
        self.assertNotIn('"User-Agent": "Xcode"', result)
        with self.assertRaises(ValueError):
            patch_source(result)

    def test_ci_runs_patch_after_compatibility_decoder(self):
        for name in ('build.yml', 'simulator-ui.yml'):
            flow = (ROOT / '.github/workflows' / name).read_text()
            self.assertLess(flow.index('patch_stossign_api_response.py'), flow.index('patch_stossign_identity.py'))

    def test_selected_preset_is_not_overridden_before_capability_update(self):
        caller = (ROOT / 'GetMoreRam/SideStoreAuthentication.swift').read_text()
        helper = (ROOT / 'GetMoreRam/OnDeviceAnisetteHelper.swift').read_text()
        editor = (ROOT / 'GetMoreRam/AppIDViewModel.swift').read_text()
        self.assertIn('deviceDescription: effectiveInfo', caller)
        self.assertIn('defaults.string(forKey: "CustomClientInfo")', helper)
        self.assertIn('defaults.string(forKey: "CustomUserAgent")', helper)
        self.assertIn('let freshAnisette = try await AnisetteDataHelper.shared.getAnisetteData()', editor)
        self.assertIn('session: freshSession', editor)
        self.assertNotIn('Windows; 10.0', editor)

    def test_response_401_does_not_retry_mutation(self):
        patch = (ROOT / 'scripts/patch_stossign_api_response.py').read_text()
        self.assertIn('httpCode == 401', patch)
        self.assertNotIn('retry', patch)

if __name__ == '__main__':
    unittest.main()
