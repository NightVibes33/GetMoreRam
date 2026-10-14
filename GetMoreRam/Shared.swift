//
//  Shared.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common

class AlertHelper<T> : ObservableObject {
    @Published var show = false
    private var result : T?
    private var c : CheckedContinuation<Void, Never>? = nil
    
    func open() async -> T? {
        await withCheckedContinuation { c in
            self.c = c
            Task { await MainActor.run {
                self.show = true
            }}
        }
        return self.result
    }
    
    func close(result: T?) {
        if let c {
            self.result = result
            c.resume()
            self.c = nil
        }
        DispatchQueue.main.async {
            self.show = false
        }

    }
}
typealias YesNoHelper = AlertHelper<Bool>

class InputHelper : AlertHelper<String> {
    @Published var initVal = ""
    
    func open(initVal: String) async -> String? {
        self.initVal = initVal
        return await super.open()
    }
    
    override func open() async -> String? {
        self.initVal = ""
        return await super.open()
    }
}

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
        
//    private static var enBundle : Bundle? = {
//        let language = "en"
//        let path = Bundle.main.path(forResource:language, ofType: "lproj")
//        let bundle = Bundle(path: path!)
//        return bundle
//    }()
    
    var loc: String {
//        let message = NSLocalizedString(self, comment: "")
//        if message != self {
//            return message
//        }
//
//        if let forcedString = String.enBundle?.localizedString(forKey: self, value: nil, table: nil){
//            return forcedString
//        }else {
            return self
//        }
    }
    
    func localizeWithFormat(_ arguments: CVarArg...) -> String{
        String.localizedStringWithFormat(self.loc, arguments)
    }
    
}

class SharedModel: ObservableObject {
    @Published var isLogin = false
    @AppStorage("AnisetteServer") var anisetteServerURL = "https://ani.sidestore.io"
    var session: AppleAPISession?
    var account: Account?
    var team: Team?
    @Published var isRestoringSession = false
    @Published var sessionRestoreError: String?

    @MainActor
    func restoreSavedSession() async {
        guard !isRestoringSession, !isLogin,
              let saved = Keychain.shared.savedAppleSession else { return }
        isRestoringSession = true
        sessionRestoreError = nil
        defer { isRestoringSession = false }

        do {
            // A fresh anisette response is required: one-time codes must never be reused.
            let anisette = try await AnisetteDataHelper.shared.getAnisetteData()
            let restored = AppleAPISession(dsid: saved.dsid, authToken: saved.authToken, anisetteData: anisette)
            // Verify the saved token with Apple before declaring the account signed in.
            let verifiedAccount = try await AppleAPI.shared.fetchAccount(session: restored)
            guard verifiedAccount.appleID.caseInsensitiveCompare(saved.appleID) == .orderedSame else {
                throw "Saved Apple account does not match the verified session."
            }
            let teams = try await AppleAPI.shared.fetchTeamsForAccount(account: verifiedAccount, session: restored)
            guard let preferredTeam = teams.first(where: { $0.identifier == saved.selectedTeamID }) ?? teams.first else {
                throw "The saved Apple account has no accessible developer team."
            }
            account = verifiedAccount
            session = restored
            team = preferredTeam
            isLogin = true
            try? Keychain.shared.saveSelectedTeam(preferredTeam.identifier)
        } catch {
            // Keep the keychain token for later retries if Apple or the network is unavailable.
            sessionRestoreError = "Saved Apple session could not be restored: \(error.localizedDescription)"
            session = nil
            account = nil
            team = nil
            isLogin = false
        }
    }

    @MainActor
    func signOut() {
        Keychain.shared.clearSavedAppleSession()
        Keychain.shared.appleIDEmailAddress = nil
        Keychain.shared.appleIDPassword = nil
        session = nil
        account = nil
        team = nil
        isLogin = false
        sessionRestoreError = nil
    }
    
    init() {
        AnisetteDataHelper.shared.url = URL(string: anisetteServerURL)
    }
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
}

extension Error {
    var detailedDescription: String {
        let localizedError = self as? LocalizedError
        var lines: [String] = []
        
        if let description = localizedError?.errorDescription, !description.isEmpty {
            lines.append(description)
        } else {
            let nsError = self as NSError
            lines.append(nsError.localizedDescription)
        }
        
        if let failureReason = localizedError?.failureReason, !failureReason.isEmpty {
            lines.append("Reason: \(failureReason)")
        }
        
        if let recoverySuggestion = localizedError?.recoverySuggestion, !recoverySuggestion.isEmpty {
            lines.append("Suggestion: \(recoverySuggestion)")
        }
        
        let nsError = self as NSError
        if nsError.domain != NSCocoaErrorDomain || nsError.code != 0 {
            lines.append("Domain: \(nsError.domain)")
            lines.append("Code: \(nsError.code)")
        }
        
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            lines.append("Underlying: \(underlying.detailedDescription)")
        }
        
        return lines.joined(separator: "\n")
    }
}
