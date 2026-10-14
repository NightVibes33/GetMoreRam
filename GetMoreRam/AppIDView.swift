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
    
    var body: some View {
        Form {
            Section {
                Button {
                    Task { await addIncreasedMemoryLimit() }
                } label: {
                    Text("Add Increased Memory Limit")
                }
            } footer: {
                Text("After enabling, re-sign and reinstall the target app using SideStore to obtain a new provisioning profile. This does not change the already-installed copy.")
            }

            Section {
                Text(viewModel.result)
                    .font(.system(.subheadline, design: .monospaced))
            } header: {
                Text("Server Response")
            }
        }
        .alert("Error", isPresented: $errorShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(errorInfo)
        }
        .navigationTitle(viewModel.bundleID)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func addIncreasedMemoryLimit() async {
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
                             ? "Tap Refresh to load your developer App IDs."
                             : "No matching App IDs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredAppIDs, id: \.self) { appID in
                            NavigationLink {
                                AppIDEditView(viewModel: appID)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(appID.appID.name)
                                        .font(.headline)
                                    Text(appID.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("App IDs")
                }

                Section {
                    Button("Refresh") {
                        Task { await refreshButtonClicked() }
                    }
                }
            }
            .navigationTitle("App IDs")
            .navigationBarTitleDisplayMode(.inline)
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
    
    func refreshButtonClicked() async {
        do {
            try await viewModel.fetchAppIDs()
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
}
