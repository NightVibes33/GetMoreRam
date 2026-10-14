import SwiftUI

struct ContentView: View {
    @StateObject private var appIDs = AppIDViewModel()
    @StateObject private var login = LoginViewModel()
    @State private var selectedTab = 0

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

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Increased Memory Limit").font(.title2.bold())
                    Text("Choose an App ID to request Apple's Increased Memory Limit capability.")
                        .foregroundStyle(.secondary)
                    Button("Select App ID") { selectedTab = 1 }
                        .buttonStyle(.borderedProminent)
                    Text("A successful request does not modify the installed app. Re-sign and reinstall with SideStore to obtain updated entitlements.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .navigationTitle("Memory")
            }
            .tabItem { Label("Memory", systemImage: "memorychip") }.tag(2)

            NavigationStack {
                SettingsView(viewModel: login)
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(3)
        }
        .environmentObject(DataManager.shared.model)
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
