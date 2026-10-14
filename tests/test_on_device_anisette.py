"""ClientQUI v1.0 ODA integration regression tests.

Live login requires on-device verification. Keep SideSign as the authentication
engine on every iOS version, with on-device anisette by default.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
def source(name): return (ROOT / "GetMoreRam" / name).read_text()


class OnDeviceAnisetteTests(unittest.TestCase):
    def test_on_device_is_the_default_but_remote_is_user_selectable(self):
        self.assertIn('@AppStorage("UseOnDeviceAnisette") var useOnDeviceAnisette = true', source("Shared.swift"))
        self.assertIn('UserDefaults.standard.object(forKey: "UseOnDeviceAnisette") == nil', source("AnisetteDataHelper.swift"))
        self.assertIn('OnDeviceAnisetteHelper.shared.getAnisetteData()', source("AnisetteDataHelper.swift"))
        self.assertIn('Toggle("On-device Anisette"', source("SettingsView.swift"))
        self.assertIn('if !sharedModel.useOnDeviceAnisette', source("SettingsView.swift"))

    def test_exact_upstream_oda_engine_and_client(self):
        code = source("OnDeviceAnisetteHelper.swift")
        self.assertIn("SideSign.AnisetteDataManager.shared", code)
        self.assertIn("AnisetteRequestHeaders().with", code)
        self.assertIn(".remoteODA(sourceURL: metadataURL, fallbackURL: metadataURL)", code)
        self.assertIn('https://zzz.haus/oda.json', code)
        self.assertIn('Keychain.shared.adiPb = nil', code)
        self.assertIn("StosSign_Common.AnisetteData(", code)

    def test_does_not_revert_side_sign_login(self):
        self.assertIn("SideStoreAuthentication.authenticate(", source("LoginViewModel.swift"))
        self.assertIn("sideSignContinuation", source("LoginViewModel.swift"))
        self.assertIn("AnisetteDataHelper.shared.getAnisetteData()", source("Shared.swift"))

    def test_xcode_has_explicit_anisettekit_product(self):
        project = (ROOT / "GetMoreRam.xcodeproj" / "project.pbxproj").read_text()
        self.assertIn("https://github.com/mahee96/AnisetteKit", project)
        self.assertIn("productName = AnisetteKit;", project)
        self.assertIn("IPHONEOS_DEPLOYMENT_TARGET = 18.0;", project)


if __name__ == "__main__":
    unittest.main()
