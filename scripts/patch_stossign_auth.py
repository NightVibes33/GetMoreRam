#!/usr/bin/env python3
"""Patch the pinned StosSign checkout for consistent Apple authentication headers.

This only changes the temporary copy in the Xcode Actions runner.
"""
import pathlib
import sys

USER_AGENT = "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"


def replace_exact(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise ValueError(f"{label}: pinned StosSign source mismatch (found {count})")
    return source.replace(old, new)


def patch_source(source: str) -> str:
    # GrandSlam initial authentication and app token requests.
    source = replace_exact(
        source,
        '"User-Agent": "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.dt.Xcode/26.0)",',
        '"User-Agent": "' + USER_AGENT + '",',
        "GrandSlam User-Agent",
    )

    # Trusted device / SMS verification requests must use the same profile.
    source = replace_exact(
        source,
        '"User-Agent": "Xcode",',
        '"User-Agent": "' + USER_AGENT + '",',
        "2FA User-Agent",
    )

    # -22411 is a genuine server error; DO NOT silently interpret it as 2FA
    # success or show a fake verification field without a challenge token.
    # Record which GSA protocol step returned the error for accurate diagnosis.
    source = replace_exact(
        source,
        r'let localizedDescription = "\(errorDescription) (\(errorCode))"',
        'let stage = requestParameters["o"] as? String ?? "unknown"\n'
        r'                let localizedDescription = "[GSA stage: \(stage)] \(errorDescription) (\(errorCode))"',
        "GrandSlam error-stage diagnostics",
    )
    return source


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_stossign_auth.py path/to/Authentication.swift")
    path = pathlib.Path(sys.argv[1])
    source = path.read_text(encoding="utf-8")
    patched = patch_source(source)
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(patched, encoding="utf-8")
    print("StosSign GSA and 2FA User-Agent set to AuthKit macOS 26.6; Pixel 7 Client-Info comes from anisette.")
    print("Apple authentication errors now contain the failing GSA stage; no tokens printed.")


if __name__ == "__main__":
    main()
