#!/usr/bin/env python3
"""Resilient decoder for pinned StosSign Apple developer API responses.

Do not modify headers or authentication. Keep SideSign on every iOS version.
Do not emit response bodies, tokens, or developer-account data to logs.
"""
import pathlib
import sys


def once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise ValueError(f"{label}: source mismatch ({n})")
    return text.replace(old, new)


def patch_range(src: str, start: str, end: str, modifier) -> str:
    a = src.index("    public func " + start + "(")
    b = src.index("    public func " + end + "(", a)
    return src[:a] + modifier(src[a:b]) + src[b:]


def with_response(body: str, label: str) -> str:
    return once(
        body,
        "        let (data, _) = try await self.session.data(for: request)",
        r'''        let (data, response) = try await self.session.data(for: request)
        let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let mime = (response as? HTTPURLResponse)?.mimeType ?? "unknown"
        guard (200...299).contains(httpCode) else {
            let hint = httpCode == 401
                ? " Sign out and sign in again after selecting your Client Identity in Settings. Verify the selected developer team has permission for this App ID."
                : ""
            throw NSError(domain: "GetMoreRam.AppleResponse", code: httpCode,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Apple developer request returned HTTP \(httpCode) (\(mime)).\(hint)"])
        }''',
        label,
    )


def patch_source(src: str) -> str:
    def edit(body: str) -> str:
        body = with_response(body, "sendEditRequest")
        old = '''        if json {
            guard let responseDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        } else {
            guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw AppleAPIError.badServerResponse
            }
            
            return responseDictionary
        }'''
        new = r'''        if json {
            if let dictionary = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
                return dictionary
            }
        }
        if let dictionary = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
            return dictionary
        }
        if let dictionary = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
            return dictionary
        }
        throw NSError(domain: "GetMoreRam.AppleResponse", code: 3840,
            userInfo: [NSLocalizedDescriptionKey:
                "Apple capability API returned neither plist nor JSON (HTTP \(httpCode), \(mime), \(data.count) bytes)."])'''
        return once(body, old, new, "sendEditRequest parser")

    def list_request(body: str) -> str:
        body = with_response(body, "sendRequestWithURL")
        old = '''        guard let responseDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw AppleAPIError.badServerResponse
        }
        
        return responseDictionary'''
        new = r'''        if let dictionary = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] {
            return dictionary
        }
        if let dictionary = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
            return dictionary
        }
        throw NSError(domain: "GetMoreRam.AppleResponse", code: 3840,
            userInfo: [NSLocalizedDescriptionKey:
                "Apple developer API returned neither plist nor JSON (HTTP \(httpCode), \(mime), \(data.count) bytes)."])'''
        return once(body, old, new, "sendRequestWithURL parser")

    src = patch_range(src, "sendEditRequest", "sendRequestWithURL", edit)
    return patch_range(src, "sendRequestWithURL", "fetchAccount", list_request)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_stossign_api_response.py /path/to/AppleAPI.swift")
    path = pathlib.Path(sys.argv[1])
    patched = patch_source(path.read_text(encoding="utf-8"))
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(patched, encoding="utf-8")
    print("StosSign Apple API plist/JSON response parsing updated; SideSign login unchanged.")


if __name__ == "__main__":
    main()
