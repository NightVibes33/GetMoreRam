//
//  SettingsView.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/14.
//

import SwiftUI
import UniformTypeIdentifiers
import StosSign_API
import StosSign_Auth
import StosSign_Common

struct SettingsView: View {

    @AppStorage("CustomClientInfo") private var customClientInfo = ""
    @AppStorage("CustomUserAgent") private var customUserAgent = ""
    @State private var identityPreset = "Custom"
    private let androidInfo = "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    private let macInfo = "<MacBookPro18,3> <Mac OS X;14.5;23F79> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    private let windowsInfo = "<PC> <Windows;10;19045> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    @State var email = ""
    @State var teamId = ""
    @StateObject var viewModel : LoginViewModel
    @EnvironmentObject private var sharedModel : SharedModel
    
    @State private var errorShow = false
    @State private var errorInfo = ""
    @State private var importResultShow = false
    @State private var importResultInfo = ""
    @State private var isImportingSideStoreAccount = false
    

    private var appVersionLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {

            Section {
                if sharedModel.isLogin {
                    LabeledContent("Email", value: sharedModel.account?.appleID ?? email)
                    LabeledContent("Team ID", value: sharedModel.team?.identifier ?? teamId)
                    Button("Sign Out", role: .destructive) {
                        sharedModel.signOut()
                        viewModel.availableTeams = []
                        email = ""
                        teamId = ""
                    }
                } else {
                    if sharedModel.isRestoringSession {
                        ProgressView("Restoring saved Apple session…")
                    }
                    if let restoreError = sharedModel.sessionRestoreError {
                        Text(restoreError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Retry Saved Login") {
                            Task { await sharedModel.restoreSavedSession() }
                        }
                        .disabled(sharedModel.isRestoringSession)
                    }
                    Button("Sign in") {
                        viewModel.loginModalShow = true
                    }
                    
                    Button("Import SideStore Account") {
                        isImportingSideStoreAccount = true
                    }
                }
            } header: {
                Text("Account")
            }
            
            Section {
                Toggle("On-device Anisette", isOn: $sharedModel.useOnDeviceAnisette)
            } footer: {
                Text("Generates anisette locally using SideStore’s ODA engine. On first use, the ODA runtime is downloaded and cached. Turn this off to use the remote V3 server below.")
            }

            if !sharedModel.useOnDeviceAnisette {
                Section {
                    HStack {
                        Text("Anisette Server URL")
                    Spacer()
                    TextField("", text: $sharedModel.anisetteServerURL)
                        .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Remote anisette V3 fallback. This server is only used when on-device Anisette is disabled.")
                }
            }

            Section {
                Picker("Identity Preset", selection: $identityPreset) {
                    Text("Custom").tag("Custom")
                    Text("Android").tag("Android")
                    Text("macOS").tag("macOS")
                    Text("Windows").tag("Windows")
                }
                .onChange(of: identityPreset) { _, selection in
                    switch selection {
                    case "Android":
                        customClientInfo = androidInfo
                        customUserAgent = "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"
                    case "macOS":
                        customClientInfo = macInfo
                        customUserAgent = "AuthKit/1 (Macintosh; OS X 14.5) (com.apple.akd/1.0)"
                    case "Windows":
                        customClientInfo = windowsInfo
                        customUserAgent = "AuthKit/1 (Windows; 10.0) (com.apple.akd/1.0)"
                    default: break
                    }
                }
                TextField("Client-Info (Apple header)", text: $customClientInfo, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("User-Agent", text: $customUserAgent, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Reset to defaults") {
                    customClientInfo = ""
                    customUserAgent = ""
                    identityPreset = "Custom"
                }
            } header: {
                Text("Authentication Identity")
            } footer: {
                Text("Overrides the Client-Info and User-Agent used by remote V3 provisioning. On-device ODA supplies its own identity; these fields do not override SideSign's authentication headers.")
            }

            Section {
                LabeledContent("App Version", value: appVersionLabel)
                LabeledContent("Anisette Mode", value: sharedModel.useOnDeviceAnisette ? "On-device ODA" : "Remote V3")
            } header: {
                Text("Build Information")
            }

            Section {
                Button("Clean Up Keychain") {
                    cleanUp()
                }
            } footer: {
                Text("If something went wrong during signing in, please try to clean up the keychain, repoen the app and try again. \n \nIf you use SideStore and are already signed in, please also try exporting SideStore Account from SideStore settings and import it here to sign in.")
            }
        }
        .alert("Error", isPresented: $errorShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(errorInfo)
        }
        .alert("SideStore Account", isPresented: $importResultShow){
            Button("OK".loc, action: {
            })
        } message: {
            Text(importResultInfo)
        }
        .fileImporter(
            isPresented: $isImportingSideStoreAccount,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importSideStoreAccount(result)
        }
        
        .sheet(isPresented: $viewModel.loginModalShow, onDismiss: {
            viewModel.cancelAuthentication()
        }) {
            loginModal
        }
        .sheet(isPresented: $viewModel.teamSelectionShow) {
            teamSelectionView
        }
    }
    
    var loginModal: some View {
        NavigationView {
            Form {
                Section {
                    TextField("", text: $viewModel.appleID)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Apple ID")
                }
                Section {
                    SecureField("", text: $viewModel.password)
                        .disabled(viewModel.isLoginInProgress)
                } header: {
                    Text("Password")
                }
                Section {
                    LabeledContent("Client-Info", value: customClientInfo.isEmpty ? "Default" : customClientInfo)
                    LabeledContent("User-Agent", value: customUserAgent.isEmpty ? "Default" : customUserAgent)
                } header: {
                    Text("Authentication identity")
                }
                if viewModel.choosingDelivery {
                    Section {
                        Picker("Delivery method", selection: $viewModel.selectedDeliveryChoice) {
                            ForEach(viewModel.verificationChoices) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        Button("Request Verification Code") {
                            viewModel.submitDeliveryChoice()
                        }
                    } header: {
                        Text("Apple two-factor authentication")
                    }
                }
                if viewModel.needVerificationCode {
                    Section {
                        TextField("6-digit code", text: $viewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .disabled(viewModel.isVerificationCodeSubmitting)
                    } header: {
                        Text("Verification Code")
                    } footer: {
                        Text(viewModel.verificationMessage)
                    }
                }
                if let loginError = viewModel.loginError {
                    Section {
                        Text(loginError)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    } header: {
                        Text("Sign-in error")
                    }
                }
                Section {
                    Button {
                        Task { await loginButtonClicked() }
                    } label: {
                        HStack {
                            if viewModel.isVerificationCodeSubmitting {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text(viewModel.isVerificationCodeSubmitting ? "Verifying Code…" :
                                 viewModel.needVerificationCode ? "Submit Code" :
                                 viewModel.choosingDelivery ? "Request Verification Code" : "Continue")
                        }
                    }
                    .disabled(continueButtonDisabled)
                }
                
                Section {
                    Text(viewModel.loginStage)
                        .foregroundStyle(.secondary)
                    Text(viewModel.logs)
                        .font(.system(.subheadline, design: .monospaced))
                } header: {
                    Text("Debugging")
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        viewModel.cancelAuthentication()
                        viewModel.loginModalShow = false
                    }
                }
            }
        }
        .onAppear {
            if let email = Keychain.shared.appleIDEmailAddress, let password = Keychain.shared.appleIDPassword {
                viewModel.appleID = email
                viewModel.password = password
            }
        }
    }
    
    var teamSelectionView: some View {
        NavigationView {
            List {
                ForEach(Array(viewModel.availableTeams.enumerated()), id: \.offset) { _, team in
                    Button {
                        selectTeam(team)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .foregroundStyle(.primary)
                            Text("\(team.identifier) · \(teamTypeDescription(team.type))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Choose Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) {
                        cancelTeamSelection()
                    }
                }
            }
        }
    }
    
    func loginButtonClicked() async {
        do {
            if viewModel.choosingDelivery {
                viewModel.submitDeliveryChoice()
                return
            }
            if viewModel.needVerificationCode {
                viewModel.submitVerificationCode()
                return
            }
            
            let result = try await viewModel.authenticate()
            if result {
                await MainActor.run {
                    viewModel.loginModalShow = false
                    email = sharedModel.account!.appleID
                    teamId = ""
                }

                if viewModel.availableTeams.count == 1,
                   let team = viewModel.availableTeams.first {
                    await MainActor.run {
                        selectTeam(team)
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run {
                        viewModel.teamSelectionShow = true
                    }
                }
            }
            
        } catch is CancellationError {
            return
        } catch {
            if let appleError = error as? AppleAPIError,
               case .customError(let code, _) = appleError,
               code == -22411 {
                if error.localizedDescription.contains("[GSA stage: apptokens]") {
                    viewModel.loginError = "Apple denied the Xcode developer-services token request (-22411). Anisette and the earlier authentication exchange succeeded, but the token was not issued. A verification code being sent does not guarantee that this final step succeeded. Check for account security prompts at account.apple.com, or retry later.\n\n" + error.detailedDescription
                } else {
                    viewModel.loginError = "Apple rejected this authentication stage (-22411). If account security verification is requested, complete it at account.apple.com before retrying.\n\n" + error.detailedDescription
                }
            } else if (error as NSError).code == 3840 {
                viewModel.loginError = "Unexpected server response during \(viewModel.loginStage). Apple developer services or anisette may have returned the wrong data format. This is not an incorrect verification code.\n\n" + error.detailedDescription
            } else {
                viewModel.loginError = error.detailedDescription
            }
        }
    }

    private var continueButtonDisabled: Bool {
        if viewModel.choosingDelivery {
            return viewModel.selectedDeliveryChoice.isEmpty
        }
        if viewModel.needVerificationCode {
            return viewModel.isVerificationCodeSubmitting ||
                viewModel.verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return viewModel.isLoginInProgress
    }
    
    func cleanUp() {
        Keychain.shared.adiPb = nil
        Keychain.shared.identifier = nil
        Keychain.shared.appleIDPassword = nil
        Keychain.shared.appleIDEmailAddress = nil
        Keychain.shared.clearSavedAppleSession()
        AnisetteDataHelper.shared.resetClientInfo()
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        sharedModel.sessionRestoreError = nil
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
        email = ""
        teamId = ""
    }
    
    func importSideStoreAccount(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw "No file selected."
            }
            
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: url)
            let account = try SideStoreAccountImporter.importAccount(from: data)
            
            viewModel.appleID = account.email
            viewModel.password = account.password
            sharedModel.session = nil
            sharedModel.account = nil
            sharedModel.team = nil
            sharedModel.isLogin = false
            viewModel.availableTeams = []
            viewModel.teamSelectionShow = false
            email = account.email
            teamId = ""
            importResultInfo = "Imported \(account.email).\nTap \"Sign In\" to continue."
            importResultShow = true
        } catch {
            errorInfo = error.detailedDescription
            errorShow = true
        }
    }
    
    func selectTeam(_ team: Team) {
        sharedModel.team = team
        sharedModel.isLogin = true
        do {
            try Keychain.shared.saveSelectedTeam(team.identifier)
        } catch {
            errorInfo = "Could not save the selected team: \(error.localizedDescription)"
            errorShow = true
        }
        email = sharedModel.account?.appleID ?? email
        teamId = team.identifier
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
    }
    
    func cancelTeamSelection() {
        viewModel.availableTeams = []
        viewModel.teamSelectionShow = false
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        email = ""
        teamId = ""
    }
    
    func teamTypeDescription(_ type: TeamType) -> String {
        switch type {
        case .free:
            return "Free"
        case .individual:
            return "Individual"
        case .organization:
            return "Organization"
        case .unknown:
            return "Unknown"
        }
    }
    
}
