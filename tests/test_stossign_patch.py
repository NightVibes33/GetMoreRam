import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from patch_stossign_auth import patch_source

PINNED_SOURCE_FIXTURE = r"""
"User-Agent": "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.dt.Xcode/26.0)",
"User-Agent": "Xcode",
let localizedDescription = "\(errorDescription) (\(errorCode))"
        let authType = statusDictionary["au"] as? String
        switch authType {
        case "trustedDeviceSecondaryAuth":
            try await requestTrustedDeviceTwoFactorCode(
                dsid: dsid,
                idmsToken: idmsToken,
                anisetteData: anisetteData,
                verificationHandler: verificationHandler
            )
        case "secondaryAuth":
        default:
            guard let sessionKey = decryptedDictionary["sk"] as? Data,
        verificationHandler: @escaping (@escaping (String?) -> Void) async -> Void
    ) async throws {
        let requestURL = URL(string: "https://gsa.apple.com/auth/verify/trusteddevice")!
        let (_, _) = try await AppleAPI.shared.session.data(for: request)
        
        let verificationCode = try await withCheckedThrowingContinuation
"""


class StosSignPatchTests(unittest.TestCase):
    def test_2fa_challenge_handling_and_token_error_diagnostics(self):
        updated = patch_source(PINNED_SOURCE_FIXTURE)
        self.assertIn('case "trustedDeviceSecondaryAuth", "trustedDevice", "pushedCode":', updated)
        self.assertIn('case "secondaryAuth", "sms", "phone", "voice":', updated)
        self.assertIn('codeAlreadySent: authType == "pushedCode"', updated)
        self.assertIn('if !codeAlreadySent', updated)
        self.assertIn('case "repair":', updated)
        self.assertIn('Unsupported Apple authentication challenge:', updated)
        self.assertIn('[GSA stage:', updated)
        self.assertEqual(updated.count('AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)'), 2)

    def test_fails_closed_if_upstream_changes(self):
        with self.assertRaises(ValueError):
            patch_source("source changed unexpectedly")


if __name__ == "__main__":
    unittest.main()
