import hashlib
import unittest
import uuid

from scripts.apple_android_probe import (
    CLIENT_INFO, ENDPOINT, USER_AGENT, build_request, validate_lookup
)


class AndroidAppleProbeTests(unittest.TestCase):
    def test_exact_pixel_7_client_info(self):
        self.assertEqual(CLIENT_INFO, "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>")
        self.assertEqual(USER_AGENT, "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)")

    def test_request_uses_consistent_ephemeral_device_identifier(self):
        identifier = uuid.UUID("12345678-1234-5678-1234-567812345678")
        request = build_request(identifier)
        self.assertEqual(request.full_url, ENDPOINT)
        self.assertEqual(request.get_method(), "GET")
        headers = {k.lower(): v for k, v in request.header_items()}
        self.assertEqual(headers["x-mme-client-info"], CLIENT_INFO)
        self.assertEqual(headers["user-agent"], USER_AGENT)
        self.assertEqual(headers["x-mme-device-id"], str(identifier).upper())
        self.assertEqual(headers["x-apple-i-md-lu"], hashlib.sha256(identifier.bytes).hexdigest().upper())

    def test_valid_plist(self):
        import plistlib
        data = plistlib.dumps({"urls": {
            "midStartProvisioning": "https://example.apple.com/start",
            "midFinishProvisioning": "https://example.apple.com/finish",
        }})
        self.assertTrue(validate_lookup(data))

    def test_rejects_unexpected_response(self):
        import plistlib
        with self.assertRaises(ValueError):
            validate_lookup(plistlib.dumps({"urls": {}}))


if __name__ == "__main__":
    unittest.main()
