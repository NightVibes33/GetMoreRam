#!/usr/bin/env python3
"""Patch pinned SideSign to handle transient Apple HTTP errors without exposing HTML.

Only replay a safe GrandSlam 'init' request and read-only developer calls.
Never automatically resend an SRP complete, app-token, 2FA or mutating request.
This patch runs against the temporary SwiftPM checkout on GitHub Actions.
"""
import pathlib
import sys

HELPER = r'''

// Local GetMoreRam compatibility patch. SwiftPM checkout only, never upstream.
enum GetMoreRamAppleTransientHTTP {
    static func data(
        for request: URLRequest,
        session: URLSession,
        operation: String,
        retrySafe: Bool
    ) async throws -> (Data, URLResponse) {
        var retries = 0
        while true {
            let result = try await session.data(for: request)
            let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
            if [502, 503, 504].contains(status) {
                if retrySafe && retries < 2 {
                    retries += 1
                    try await Task.sleep(for: .milliseconds(600 * retries))
                    continue
                }
                throw NSError(
                    domain: "GetMoreRam.AppleHTTP",
                    code: status,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Apple \(operation) returned HTTP \(status). The Apple endpoint is temporarily unavailable; this is not an Anisette response. Try again later."]
                )
            }
            return result
        }
    }
}
'''

def once(src: str, before: str, after: str, label: str) -> str:
    count = src.count(before)
    if count != 1:
        raise ValueError(f"{label}: pinned SideSign source mismatch ({count})")
    return src.replace(before, after)

def patch_auth(src: str) -> str:
    original = r'''            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("[SideSign] sendAuthenticationRequest network error: \(error)")'''
    updated = r'''            (data, response) = try await GetMoreRamAppleTransientHTTP.data(
                for: request,
                session: session,
                operation: "GrandSlam " + (requestParameters["o"] as? String ?? "authentication"),
                retrySafe: (requestParameters["o"] as? String) == "init"
            )
        } catch {
            debugLog("[SideSign] sendAuthenticationRequest network error: \(error)")'''
    src = once(src, original, updated, "GSA authentication")
    if "enum GetMoreRamAppleTransientHTTP" in src:
        raise ValueError("SideSign authentication already patched")
    return src + HELPER

def patch_portal(src: str) -> str:
    original = r'''            (data, response) = try await session.data(for: request)
        } catch {
            debugLog("[SideSign] sendRequest network error: \(error)")'''
    updated = r'''            (data, response) = try await GetMoreRamAppleTransientHTTP.data(
                for: request,
                session: session,
                operation: "developer account lookup",
                retrySafe: requestURL == Constants.URLs.viewDeveloper
                    || requestURL == Constants.URLs.listTeams
            )
        } catch {
            debugLog("[SideSign] sendRequest network error: \(error)")'''
    return once(src, original, updated, "developer account lookup")

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: patch_sidesign_apple_http.py Authentication.swift DeveloperPortalAPI.swift")
    auth = pathlib.Path(sys.argv[1])
    portal = pathlib.Path(sys.argv[2])
    patched_auth = patch_auth(auth.read_text(encoding="utf-8"))
    patched_portal = patch_portal(portal.read_text(encoding="utf-8"))
    for path, contents in ((auth, patched_auth), (portal, patched_portal)):
        path.chmod(path.stat().st_mode | 0o200)
        path.write_text(contents, encoding="utf-8")
    print("SideSign: bounded 502/503/504 retries on safe reads; no 2FA or mutation replay.")
    print("Apple failure details include operation and status; HTML and credentials withheld.")

if __name__ == "__main__":
    main()
