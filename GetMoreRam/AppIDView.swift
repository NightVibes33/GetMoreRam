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
            } header: { Text("Selected Application") }

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

