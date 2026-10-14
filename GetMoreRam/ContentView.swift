import SwiftUI

struct ContentView: View {
    @StateObject private var appIDs = AppIDViewModel()
    @StateObject private var login = LoginViewModel()
    @State private var selectedTab = 0
    @AppStorage("AppearancePreference") private var appearancePreference = "System"

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("GetMoreRam").font(.largeTitle.bold())
                        Text("Apple developer capability manager")
                            .foregroundStyle(.secondary)
                        Label("Apple Account", systemImage: "person.crop.circle")
                            .font(.headline)
                        AccountOverview()
                        Button("Manage App IDs") { selectedTab = 1 }
                            .buttonStyle(.borderedProminent)
                        Button("Increased Memory Limit") { selectedTab = 2 }
                            .buttonStyle(.bordered)
                        Text("Enable the capability for an App ID, then re-sign and reinstall that app through SideStore.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

            AppIDView(viewModel: appIDs)
                .tabItem { Label("App IDs", systemImage: "square.stack.3d.up.fill") }.tag(1)

            MemoryCapabilityView(viewModel: appIDs)
            .tabItem { Label("Memory", systemImage: "memorychip") }.tag(2)

            NavigationStack {
                SettingsView(viewModel: login)
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
        }
        .environmentObject(DataManager.shared.model)
        .preferredColorScheme(preferredAppearance)
    }
}

private struct AccountOverview: View {
    @EnvironmentObject private var model: SharedModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isLogin {
                Text(model.account?.appleID ?? "Signed in")
                Text("Team: \(model.team?.identifier ?? "Not selected")")
                    .foregroundStyle(.secondary)
            } else {
                Text("Not signed in")
                Text("Sign in from Settings to manage App IDs.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MemoryCapabilityView: View {
    @ObservedObject var viewModel: AppIDViewModel
    @State private var search = ""
    @State private var loading = false
    @State private var error: String?

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
                Section("Choose App ID") {
                    if viewModel.appIDs.isEmpty {
                        Text("Sign in and load App IDs to select a target.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(matches, id: \.self) { app in
                        NavigationLink {
                            AppIDEditView(viewModel: app)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.appID.name)
                                Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
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
            .alert("Unable to load App IDs", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) { Button("OK", role: .cancel) { error = nil } }
                message: { Text(error ?? "") }
        }
    }
}
