#!/usr/bin/env python3
"""Credential-free connectivity check for Apple's provisioning lookup using Pixel 7 identity."""
import hashlib
import os
import plistlib
import sys
import time
import uuid
import urllib.error
import urllib.request
from datetime import datetime, timezone

ENDPOINT = "https://gsa.apple.com/grandslam/GsService2/lookup"
CLIENT_INFO = "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
USER_AGENT = "AuthKit/1 (Linux; Android 14; Pixel 7) (com.apple.akd/1.0)"


def build_request(device_identifier=None):
    identifier = device_identifier or uuid.uuid4()
    local_user_id = hashlib.sha256(identifier.bytes).hexdigest().upper()
    headers = {
        "X-MMe-Client-Info": CLIENT_INFO,
        "User-Agent": USER_AGENT,
        "Content-Type": "text/x-xml-plist",
        "Accept": "*/*",
        "X-Apple-I-MD-LU": local_user_id,
        "X-Mme-Device-Id": str(identifier).upper(),
        "X-Apple-I-Client-Time": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "X-Apple-Locale": "en_US",
        "X-Apple-I-TimeZone": "UTC",
    }
    return urllib.request.Request(ENDPOINT, headers=headers, method="GET")


def validate_lookup(data):
    plist = plistlib.loads(data)
    if not isinstance(plist, dict) or not isinstance(plist.get("urls"), dict):
        raise ValueError("Expected a plist containing a URLs dictionary")
    urls = plist["urls"]
    for key in ("midStartProvisioning", "midFinishProvisioning"):
        value = urls.get(key)
        if not isinstance(value, str) or not value.startswith("https://"):
            raise ValueError("Missing valid " + key + " provisioning URL")
    return True


def record_summary(message):
    path = os.getenv("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as report:
            report.write(message + "\n")


def main():
    request = build_request()
    start = time.monotonic()
    print("Target: https://gsa.apple.com/grandslam/GsService2/lookup")
    print("X-MMe-Client-Info: " + CLIENT_INFO)
    print("User-Agent: " + USER_AGENT)
    print("No Apple ID, password, session token or anisette secret is sent.")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = response.status
            data = response.read(1024 * 1024 + 1)
            content_type = response.headers.get("Content-Type", "unspecified")
        duration = time.monotonic() - start
        if len(data) > 1024 * 1024:
            raise ValueError("Apple lookup response exceeded 1 MiB")
        validate_lookup(data)
        msg = f"PASS: Apple provisioning lookup responded HTTP {status}; valid provisioning URLs; {duration:.2f}s; Content-Type {content_type}"
        print(msg)
        record_summary("### Pixel 7 to Apple: PASS\n" + msg)
        return 0
    except urllib.error.HTTPError as exc:
        msg = f"FAIL: Apple returned HTTP {exc.code} for unauthenticated Android lookup (not an Apple ID sign-in test)"
    except (urllib.error.URLError, TimeoutError, OSError, ValueError, plistlib.InvalidFileException) as exc:
        msg = "FAIL: Apple lookup transport/format check: " + str(exc)
    print(msg, file=sys.stderr)
    record_summary("### Pixel 7 to Apple: FAIL\n" + msg)
    return 1


if __name__ == "__main__":
    sys.exit(main())
