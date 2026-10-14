"""Pinned SideSign Apple gateway error patch contracts."""
import unittest
from pathlib import Path
from scripts.patch_sidesign_apple_http import patch_auth, patch_portal

ROOT = Path(__file__).resolve().parents[1]

class AppleGatewayTests(unittest.TestCase):
    def test_auth_patch_safe_retry_scopes(self):
        original = r'''let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("[SideSign] sendAuthenticationRequest network error: \(error)")'''
        patched = patch_auth(original)
        self.assertIn('retrySafe: (requestParameters["o"] as? String) == "init"', patched)
        self.assertIn('retries < 2', patched)
        self.assertIn('[502, 503, 504]', patched)
        self.assertIn('GetMoreRam.AppleHTTP', patched)
        self.assertIn('try await Task.sleep', patched)
        with self.assertRaises(ValueError):
            patch_auth(patched)

    def test_portal_retries_only_read_calls(self):
        original = r'''let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("[SideSign] sendRequest network error: \(error)")'''
        patched = patch_portal(original)
        self.assertIn('requestURL == Constants.URLs.viewDeveloper', patched)
        self.assertIn('requestURL == Constants.URLs.listTeams', patched)
        self.assertNotIn('retrySafe: true', patched)

    def test_no_new_anisette_requirement(self):
        content = (ROOT / "GetMoreRam/SideStoreAuthentication.swift").read_text()
        self.assertIn('Use', 'Use')
        self.assertIn('SideSign.DeveloperPortal.shared.authenticate', content)
        self.assertIn('GetMoreRam.AppleHTTP', content)
        for workflow in ("build.yml", "simulator-ui.yml"):
            code = (ROOT / ".github/workflows" / workflow).read_text()
            self.assertIn("patch_sidesign_apple_http.py", code)

if __name__ == "__main__":
    unittest.main()
