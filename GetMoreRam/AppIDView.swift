//
//  AppIDView.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI

struct AppIDEditView : View {
    @StateObject var viewModel : AppIDModel
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var submitting = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 13) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.purple)
                        .frame(width: 52, height: 52)
                        .background(.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.appID.name).font(.headline)
                        Text(viewModel.bundleID)
                            .font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 8)
                LabeledContent("App ID", value: viewModel.appID.identifier)
                    .font(.caption)
            } header: { Text("Selected Apple Developer App ID") }

            Section {
                Button {
                    Task { await addIncreasedMemoryLimit() }
                } label: {
                    HStack(spacing: 9) {
                        if submitting { ProgressView() }
                        Image(systemName: "memorychip")
                        Text(submitting ? "Submitting Request…" : "Add Increased Memory Limit")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(submitting)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } footer: {
                Text("After enabling, re-sign and reinstall the target app using SideStore to obtain a new provisioning profile. This does not change the already-installed copy.")
            }

            if !viewModel.result.isEmpty {
                Section {
                    Text("Apple returned a response to the capability update request. This does not verify the entitlement in the installed app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(viewModel.result)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    Text("Server Response")
                }
            }
        }
        .alert("Error", isPresented: $errorShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(errorInfo)
        }
        .navigationTitle("Memory Limit")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @MainActor
    func addIncreasedMemoryLimit() async {
        guard !submitting else { return }
        submitting = true
        defer { submitting = false }
        do {
            try await viewModel.addIncreasedMemory()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}


struct AppIDView : View {
    @StateObject var viewModel : AppIDViewModel
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var isRefreshing = false
    @EnvironmentObject private var account: SharedModel
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool

    private var filteredAppIDs: [AppIDModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.appIDs }

        return viewModel.appIDs.filter { app in
            app.appID.name.localizedStandardContains(query) ||
            app.bundleID.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 27, weight: .medium))
                            .foregroundStyle(.cyan)
                            .frame(width: 49, height: 49)
                            .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Developer App IDs")
                                .font(.headline)
                            Text(account.isLogin
                                 ? (account.team?.name ?? "Selected Developer Team")
                                 : "Sign in from Settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(viewModel.appIDs.count)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                } footer: {
                    Text("These are App IDs registered to the selected Apple developer team. They are not an inventory of installed apps.")
                }
                if isSearchPresented {
                    Section {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)

                            TextField("Search app name or bundle ID", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .onAppear { isSearchFocused = true }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear Search")
                            }
                        }
                    } header: {
                        Text("Search")
                    }
                }

                Section {
                    if filteredAppIDs.isEmpty {
                        Text(viewModel.appIDs.isEmpty
                             ? (account.isLogin ? "Tap Refresh to load your developer App IDs." : "Sign in under Settings, then refresh.")
                             : "No matching App IDs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredAppIDs, id: \.self) { appID in
                            NavigationLink {
                                AppIDEditView(viewModel: appID)
                            } label: {
                                HStack(spacing: 11) {
                                  Image(systemName: "app.badge")
                                    .font(.title3)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 34, height: 34)
                                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                                  VStack(alignment: .leading, spacing: 3) {
                                    Text(appID.appID.name)
                                        .font(.headline)
                                    Text(appID.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                  }
                                }
                            }
                        }
                    }
                } header: {
                    Text("App IDs")
                }

                Section {
                    Button {
                        Task { await refreshButtonClicked() }
                    } label: {
                        HStack {
                            if isRefreshing { ProgressView().padding(.trailing, 4) }
                            Label(isRefreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing || !account.isLogin)
                }
            }
            .navigationTitle("App IDs")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isSearchPresented {
                            searchText = ""
                            isSearchFocused = false
                        }
                        isSearchPresented.toggle()
                    } label: {
                        Label(isSearchPresented ? "Close Search" : "Search App IDs",
                              systemImage: isSearchPresented ? "xmark" : "magnifyingglass")
                    }
                    .accessibilityLabel(isSearchPresented ? "Close Search" : "Search App IDs")
                }
            }
            .alert("Error", isPresented: $errorShow){
                Button("OK".loc, action: {
                })
            } message: {
                Text(errorInfo)
            }
        }
    }
    
    @MainActor
    func refreshButtonClicked() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await viewModel.fetchAppIDs()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}
