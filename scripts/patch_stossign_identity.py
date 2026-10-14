#!/usr/bin/env python3
"""Apply the active GetMoreRam Client Identity to StosSign Developer API requests.

The pinned StosSign implementation hardcodes User-Agent=Xcode and an Xcode 27
beta version in its v1 and QH request dispatchers. SideSign login uses the
user-selected identity and Xcode 26, so this patch aligns the requests.
Only request headers change; no identity or credentials are hardcoded in the
resulting IPA. These changes apply to a temporary SwiftPM checkout.
"""
from pathlib import Path
import sys

METHODS = ("sendServicesRequest", "sendEditRequest", "sendRequestWithURL")

HELPERS = r'''
    // The active identity is stored by SettingsView using @AppStorage.
    // It must be resolved on every request, so Android/Windows/macOS/Custom
    // each work without rebuilding the app or forcing a particular preset.
    private func getMoreRamDeveloperClientInfo(for session: AppleAPISession) -> String {
        if let configured = UserDefaults.standard.string(forKey: "CustomClientInfo")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !configured.isEmpty {
            return configured
        }
        return session.anisetteData.deviceDescription
    }

    private func getMoreRamDeveloperUserAgent() -> String {
        if let configured = UserDefaults.standard.string(forKey: "CustomUserAgent")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !configured.isEmpty {
            return configured
        }
        let defaults = UserDefaults.standard
        let onDevice = defaults.object(forKey: "UseOnDeviceAnisette") == nil
            || defaults.bool(forKey: "UseOnDeviceAnisette")
        return onDevice
            ? "AuthKit/1 (Android; Android 14) (com.apple.akd/1.0)"
            : "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"
    }
'''

def patch_source(src: str) -> str:
    # The full pinned API contains three separate Apple developer dispatchers.
    old_ua = '"User-Agent": "Xcode",'
    old_info = '"X-MMe-Client-Info": session.anisetteData.deviceDescription,'
    old_xcode = '"X-Xcode-Version": "27.0 (27A5218g)",'
    for value, label in ((old_ua, "user agent"), (old_info, "client info"), (old_xcode, "Xcode version")):
        count = src.count(value)
        if count != len(METHODS):
            raise ValueError(f"StosSign {label}: pinned source mismatch (found {count}, expected 3)")
    src = src.replace(old_ua, '"User-Agent": getMoreRamDeveloperUserAgent(),')
    src = src.replace(old_info, '"X-MMe-Client-Info": getMoreRamDeveloperClientInfo(for: session),')
    # Match SideSign login's advertised Xcode version and avoid the obsolete
    # hardcoded iOS 27 beta Xcode build identifier.
    src = src.replace(old_xcode, '"X-Xcode-Version": "26.0 (26A242)",')
    anchor = '    private init() {}'
    if src.count(anchor) != 1:
        raise ValueError("AppleAPI initializer: pinned source mismatch")
    return src.replace(anchor, anchor + "\n" + HELPERS)

def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_stossign_identity.py /path/to/AppleAPI.swift")
    path = Path(sys.argv[1])
    patched = patch_source(path.read_text(encoding="utf-8"))
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(patched, encoding="utf-8")
    print("StosSign: QH/v1 capability headers use active Settings identity; Xcode version aligns with SideSign.")

if __name__ == "__main__":
    main()
