"""Regression checks for iOS 26's NSCocoaErrorDomain 3840 response paths."""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from patch_stossign_api_response import patch_source

FIXTURE = '''    public func sendEditRequest(
        let (data, _) = try await self.session.data(for: request)
        if json {
            guard let responseDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        } else {
            guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        }
    }
    public func sendRequestWithURL(
        let (data, _) = try await self.session.data(for: request)
        guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw AppleAPIError.badServerResponse
        }
        
        return responseDictionary
    }
    public func fetchAccount('''


class IOS26ResponseTests(unittest.TestCase):
    def test_allows_api_json_fallback_and_identifies_non_plist_data(self):
        patched = patch_source(FIXTURE)
        self.assertEqual(patched.count("GetMoreRam.AppleResponse"), 4)
        self.assertIn('let mime = (response as? HTTPURLResponse)?.mimeType ?? "unknown"', patched)
        self.assertIn("neither plist nor JSON", patched)
        self.assertNotIn("String(data: data", patched)

    def test_fails_closed_if_dependency_changes(self):
        with self.assertRaises((ValueError, IndexError)):
            patch_source(FIXTURE.replace("let (data, _) = try await self.session.data(for: request)", "let x = y"))

    def test_side_sign_retained_on_all_ios_versions(self):
        text = (ROOT / "GetMoreRam/LoginViewModel.swift").read_text()
        self.assertIn("SideStoreAuthentication.authenticate(", text)
        self.assertIn('loginStage = "Failed during \\(failedStage)"', text)

    def test_anisette_invalid_json_no_longer_exposes_raw_3840(self):
        text = (ROOT / "GetMoreRam/AnisetteDataHelper.swift").read_text()
        self.assertIn('if let json = (try? JSONSerialization.jsonObject(with: data, options: []))', text)
        self.assertIn("Anisette V3 returned an unreadable response", text)
        self.assertIn('UserDefaults.standard.string(forKey: "AnisetteServer")', text)

    def test_ci_installs_decoder_patch(self):
        text = (ROOT / ".github/workflows/build.yml").read_text()
        self.assertIn("scripts/patch_stossign_api_response.py", text)


if __name__ == "__main__":
    unittest.main()
