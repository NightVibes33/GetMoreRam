import Foundation
import SwiftUI
import UIKit
import CryptoKit

// Discovers genuine sideload-source icon URLs by matching registered bundle IDs.
// No App Store API and no installed application scan.
@MainActor
final class AppIconArtworkStore: ObservableObject {
    static let defaultSources = """
    https://apps.sidestore.io/
    https://community-apps.sidestore.io/sidecommunity.json
    """

    @Published private(set) var generation = 0
    @Published private(set) var status = "Icon lookup starts when applications load"
    private let images = NSCache<NSString, UIImage>()
    private var lastLookup = ""
    private var lastLookupDate = Date.distantPast

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SideloadIconCache", isDirectory: true)
    }

    private func fileURL(for bundleID: String) -> URL {
        let normalized = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(hash).appendingPathExtension("png")
    }

    func icon(for bundleID: String) -> UIImage? {
        let url = fileURL(for: bundleID)
        let key = url.lastPathComponent as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        images.setObject(image, forKey: key)
        return image
    }

    private func store(_ bytes: Data, for bundleID: String) {
        guard bytes.count < 8_000_000,
              let icon = UIImage(data: bytes),
              icon.size.width >= 16, icon.size.height >= 16,
              let png = icon.pngData(), png.count < 12_000_000 else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = fileURL(for: bundleID)
            try png.write(to: url, options: .atomic)
            images.setObject(icon, forKey: url.lastPathComponent as NSString)
            generation += 1
        } catch {
            status = "Unable to cache icon artwork: " + error.localizedDescription
        }
    }

    func refresh(bundleIDs: [String], sources: String) async {
        let identifiers = Array(Set(bundleIDs.filter { !$0.isEmpty })).sorted()
        guard !identifiers.isEmpty else {
            status = "Load applications to resolve icons"
            return
        }
        let feedURLs = sources.split(whereSeparator: \.isNewline)
            .compactMap { URL(string: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0.scheme?.lowercased() == "https" }
        let lookup = identifiers.joined(separator: "\n") + "\n" +
            feedURLs.map(\.absoluteString).joined(separator: "\n")
        guard lookup != lastLookup || Date().timeIntervalSince(lastLookupDate) > 1800 else { return }
        lastLookup = lookup
        lastLookupDate = Date()
        status = "Resolving icons from sideload sources…"
        var links: [String: URL] = [:]
        let requested = Set(identifiers.map { $0.lowercased() })

        // Download whole public catalogs, not per-account requests.
        // The source servers are not sent the user's application list.
        for feed in feedURLs {
            do {
                var request = URLRequest(url: feed)
                request.timeoutInterval = 14
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)
                guard data.count < 6_000_000,
                      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let apps = root["apps"] as? [[String: Any]] else { continue }
                for app in apps {
                    guard let id = app["bundleIdentifier"] as? String,
                          requested.contains(id.lowercased()),
                          let rawIcon = app["iconURL"] as? String,
                          let iconURL = URL(string: rawIcon, relativeTo: feed)?.absoluteURL,
                          iconURL.scheme?.lowercased() == "https" else { continue }
                    // An exact bundle-ID match is required; never guess from the app name.
                    if links[id.lowercased()] == nil { links[id.lowercased()] = iconURL }
                }
            } catch {
                continue
            }
        }

        let pending = identifiers.compactMap { id -> (String, URL)? in
            guard icon(for: id) == nil, let url = links[id.lowercased()] else { return nil }
            return (id, url)
        }
        // Bound concurrency and download only icons, never full IPA files.
        for start in stride(from: 0, to: pending.count, by: 6) {
            let batch = Array(pending[start..<min(start + 6, pending.count)])
            await withTaskGroup(of: (String, Data?).self) { group in
                for (id, url) in batch {
                    group.addTask {
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 12
                        do {
                            let (bytes, _) = try await URLSession.shared.data(for: request)
                            return (id, bytes.count <= 8_000_000 ? bytes : nil)
                        } catch {
                            return (id, nil)
                        }
                    }
                }
                for await (id, bytes) in group {
                    if let bytes { store(bytes, for: id) }
                }
            }
        }
        let count = identifiers.filter { icon(for: $0) != nil }.count
        status = String(count) + " of " + String(identifiers.count) +
            " icons resolved from sideload sources" +
            (count < identifiers.count ? " (remaining apps are not in available sources)" : "")
    }
}

struct AppArtworkIconView: View {
    let bundleID: String
    let name: String
    var size: CGFloat = 44
    @EnvironmentObject private var artwork: AppIconArtworkStore

    private var initials: String {
        let segments = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        let value = String(segments.prefix(2).compactMap(\.first)).uppercased()
        return value.isEmpty ? "?" : value
    }

    var body: some View {
        Group {
            if let icon = artwork.icon(for: bundleID) {
                Image(uiImage: icon).resizable().scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22).fill(.secondary.opacity(0.17))
                    Text(initials)
                        .font(.system(size: size * 0.29, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .accessibilityLabel(artwork.icon(for: bundleID) == nil
            ? name + " original icon unavailable" : name + " original icon")
    }
}

struct SideloadIconSourcesView: View {
    @AppStorage("SideloadIconSourceURLs") private var sources = AppIconArtworkStore.defaultSources
    @EnvironmentObject private var artwork: AppIconArtworkStore

    var body: some View {
        Form {
            Section {
                TextEditor(text: $sources)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 150)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Restore Default Sources") {
                    sources = AppIconArtworkStore.defaultSources
                }
            } header: {
                Text("Sideload Catalog URLs")
            } footer: {
                Text("One HTTPS AltStore/SideStore JSON source per line. Matching app icons are downloaded automatically using exact bundle identifiers; app installation is not required.")
            }
        }
        .navigationTitle("Icon Sources")
    }
}
