import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from patch_stossign_auth import patch_source


class StosSignPatchTests(unittest.TestCase):
    def test_pinned_transport_identity_and_error_stage(self):
        source = r'''
            "User-Agent": "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.dt.Xcode/26.0)",
            "User-Agent": "Xcode",
                let localizedDescription = "\(errorDescription) (\(errorCode))"
        '''
        patched = patch_source(source)
        self.assertIn('anisetteData.deviceDescription.hasPrefix("<Pixel 7> ")', patched)
        self.assertIn("Linux; Android 14; Pixel 7", patched)
        self.assertIn("[GSA stage:", patched)
        self.assertNotIn('"User-Agent": "Xcode",', patched)

    def test_upstream_source_change_requires_review(self):
        with self.assertRaises(ValueError):
            patch_source("unrecognized upstream StosSign source")


if __name__ == "__main__":
    unittest.main()
