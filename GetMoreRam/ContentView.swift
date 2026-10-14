import SwiftUI

struct ContentView: View {
    @StateObject private var appIDs = AppIDViewModel()
    @StateObject private var login = LoginViewModel()
    @StateObject private var artwork = AppIconArtworkStore()
    @State private var selectedTab: Int

    init() {
        #if DEBUG
        let requested = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("-UITestTab=") })
            .flatMap { Int($0.replacingOccurrences(of: "-UITestTab=", with: "")) }
        _selectedTab = State(initialValue: min(max(requested ?? 0, 0), 2))
        #else
        _selectedTab = State(initialValue: 0)
        #endif
    }
    @AppStorage("AppearancePreference") private var appearancePreference = "System"
    @AppStorage("SelectedAppIcon") private var selectedAppIcon = "Default"

    private var preferredAppearance: ColorScheme? {
        switch appearancePreference {
        case "Dark": return .dark
        case "Light": return .light
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeDashboard(appIDs: appIDs, selectedTab: $selectedTab)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

            MemoryCapabilityView(viewModel: appIDs)
            .tabItem { Label("Memory", systemImage: "memorychip") }.tag(1)

            NavigationStack {
                SettingsView(viewModel: login)
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(2)
        }
        .environmentObject(DataManager.shared.model)
        .environmentObject(artwork)
        .preferredColorScheme(preferredAppearance)
    }
}

private struct HomeDashboard: View {
    @ObservedObject var appIDs: AppIDViewModel
    @Binding var selectedTab: Int
    @EnvironmentObject private var account: SharedModel
    @AppStorage("SelectedAppIcon") private var selectedAppIcon = "Default"
    @State private var loading = false
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 10) {
                    Image("IconPreview-" + selectedAppIcon)
                        .resizable()
                        .frame(width: 114, height: 114)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.cyan.opacity(0.35), radius: 24)

                    HStack(spacing: 0) {
                        Text("Get").foregroundStyle(.white)
                        Text("MoreRam").foregroundStyle(.cyan)
                    }
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Increase JIT memory capability for your Apple Developer App IDs")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                Button { selectedTab = 2 } label: {
                    HStack(spacing: 13) {
                        Image(systemName: account.isLogin ? "checkmark.seal.fill" : "person.crop.circle.badge.questionmark")
                            .font(.title2)
                            .foregroundStyle(account.isLogin ? Color.green : Color.cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.isLogin ? "Signed In" : "Sign In Required")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(account.isLogin ? (account.account?.appleID ?? "Apple account") : "Connect your Apple account in Settings")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                            if account.isLogin, let team = account.team {
                                Text("Team ID  " + team.identifier)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(Color.cyan.opacity(0.3)))
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    actionTile("Memory", subtitle: "Manage capability", symbol: "memorychip",
                               first: .purple, second: .pink) { selectedTab = 1 }
                    actionTile("Refresh", subtitle: "Load applications", symbol: "arrow.clockwise",
                               first: .cyan, second: .blue) { Task { await refresh() } }
                    actionTile("Settings", subtitle: "Account & connection", symbol: "gearshape.fill",
                               first: .gray, second: .blue) { selectedTab = 2 }
                }

                if loading {
                    ProgressView("Loading applications…").tint(.cyan)
                } else if account.isLogin {
                    Text(String(appIDs.appIDs.count) + " developer applications available in Memory")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let loadError {
                    Text(loadError).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.035, blue: 0.1),
                    Color(red: 0.012, green: 0.04, blue: 0.135),
                    Color(red: 0.008, green: 0.018, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .onChange(of: account.isLogin) { _, signedIn in
            if signedIn {
                Task { await refresh() }
            } else {
                appIDs.appIDs = []
            }
        }
        .accessibilityIdentifier("screen.home")
    }

    private func actionTile(_ title: String, subtitle: String, symbol: String,
                            first: Color, second: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 0)
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 106)
            .padding(14)
            .background(
                LinearGradient(colors: [first.opacity(0.85), second.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.action." + title)
    }

    @MainActor
    private func refresh() async {
        guard account.isLogin else {
            selectedTab = 2
            return
        }
        guard !loading else { return }
        loading = true
        loadError = nil
        defer { loading = false }
        do { try await appIDs.fetchAppIDs() }
        catch { loadError = error.detailedDescription }
    }
}

private struct MemoryCapabilityView: View {
    @ObservedObject var viewModel: AppIDViewModel
    @State private var search = ""
    @State private var loading = false
    @State private var error: String?
    @AppStorage("SideloadIconSourceURLs") private var iconSources = AppIconArtworkStore.defaultSources
    @EnvironmentObject private var artwork: AppIconArtworkStore
    @EnvironmentObject private var account: SharedModel

    private var matches: [AppIDModel] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? viewModel.appIDs : viewModel.appIDs.filter {
            $0.bundleID.localizedStandardContains(q) || $0.appID.name.localizedStandardContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Request Apple's Increased Memory Limit capability for a developer App ID. This is not an adjustable RAM allocation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Applications") {
                    if viewModel.appIDs.isEmpty {
                        Text(account.isLogin ? "Refresh to load your applications." : "Sign in under Settings to load applications.")
                            .foregroundStyle(.secondary)
                    } else if matches.isEmpty {
                        Text("No matching applications.").foregroundStyle(.secondary)
                    }
                    ForEach(matches, id: \.self) { app in
                        NavigationLink {
                            AppIDEditView(viewModel: app)
                        } label: {
                            HStack(spacing: 12) {
                                AppArtworkIconView(bundleID: app.bundleID, name: app.appID.name, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.appID.name)
                                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                        Text(artwork.status).font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                } footer: {
                    Text("Original sideload-source artwork is automatically matched by bundle ID. No App Store lookup or installed-app scan.")
                }
                Section {
                    Text("After enabling, re-sign and reinstall the target IPA with SideStore. The request response alone does not verify the installed provisioning profile.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, prompt: "App name or bundle ID")
            .navigationTitle("Memory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            loading = true
                            defer { loading = false }
                            do { try await viewModel.fetchAppIDs() }
                            catch { self.error = error.localizedDescription }
                        }
                    } label: {
                        if loading { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(loading)
                }
            }
            .task(id: viewModel.appIDs.map(\.bundleID).sorted().joined(separator: "|") + "|" + iconSources) {
                if account.isLogin && viewModel.appIDs.isEmpty && !loading {
                    loading = true
                    defer { loading = false }
                    do { try await viewModel.fetchAppIDs() }
                    catch { error = error.localizedDescription }
                }
                await artwork.refresh(bundleIDs: viewModel.appIDs.map(\.bundleID), sources: iconSources)
            }
            .alert("Unable to load applications", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) { Button("OK", role: .cancel) { error = nil } }
                message: { Text(error ?? "") }
        }
    }
}
