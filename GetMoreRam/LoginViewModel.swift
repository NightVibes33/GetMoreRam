//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API
import StosSign_Auth
import StosSign_Common
import SideSign

@MainActor
class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var teamSelectionShow = false
    @Published var isLoginInProgress = false
    @Published private(set) var isVerificationCodeSubmitting = false
    @Published var logs = ""
    @Published var loginError: String? = nil
    @Published var loginStage = ""
    @Published var availableTeams: [StosSign_Common.Team] = []
    @Published var choosingDelivery = false
    @Published var verificationChoices: [DeliveryChoice] = []
    @Published var selectedDeliveryChoice = ""
    @Published var verificationMessage = ""
    
    private var verificationCodeHandler: ((String?) -> Void)?
    private var sideSignContinuation: CheckedContinuation<SideSign.TwoFactorResponse, Never>?
    private var isAuthenticationCancellationRequested = false
    
    func submitVerificationCode() {
        guard needVerificationCode, !isVerificationCodeSubmitting else { return }

        let code = verificationCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            loginError = "Enter the Apple verification code before submitting."
            return
        }

        // SideSign uses a checked continuation instead of StosSign's callback.
        // The old guard required the legacy handler, causing Submit Code to do
        // nothing even with a valid SideSign challenge on screen.
        if let continuation = sideSignContinuation {
            sideSignContinuation = nil
            loginError = nil
            isVerificationCodeSubmitting = true
            loginStage = "Verifying code with Apple"
            logs.append("Sending Apple 2FA response to SideSign (code redacted)\n")
            continuation.resume(returning: .verificationCode(code))
            return
        }

        if let handler = verificationCodeHandler {
            verificationCodeHandler = nil
            loginError = nil
            isVerificationCodeSubmitting = true
            loginStage = "Verifying code with Apple"
            logs.append("Sending Apple 2FA response to StosSign (code redacted)\n")
            handler(code)
            return
        }

        loginError = "The verification request is no longer active. Restart Apple sign-in to request a new code."
        loginStage = "Verification session expired"
    }

    func cancelAuthentication() {
        guard isLoginInProgress else { return }

        isAuthenticationCancellationRequested = true

        let verificationCodeHandler = verificationCodeHandler
        self.verificationCodeHandler = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        verificationCodeHandler?(nil)
        let sideSignContinuation = sideSignContinuation
        self.sideSignContinuation = nil
        sideSignContinuation?.resume(returning: .cancel)
        choosingDelivery = false
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        logs = ""
        loginError = nil
        loginStage = "Obtaining anisette data"
        isLoginInProgress = true
        isAuthenticationCancellationRequested = false
        
        func logging(text: String) {
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
            }
        }
        
        AnisetteDataHelper.shared.loggingFunc = logging

        defer {
            verificationCodeHandler = nil
            sideSignContinuation = nil
            choosingDelivery = false
            needVerificationCode = false
            verificationCode = ""
            isLoginInProgress = false
            isVerificationCodeSubmitting = false
            isAuthenticationCancellationRequested = false
        }

        do {
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
            loginStage = "Authenticating with Apple"

            let (account, session) = try await SideStoreAuthentication.authenticate(
                appleID: appleID,
                password: password,
                anisetteData: anisetteData,
                verificationHandler: { [weak self] request in
                    guard let self else { return .cancel }
                    return await self.requestSideStoreVerification(request)
                },
                accountRepairHandler: { [weak self] url, message in
                    await MainActor.run {
                        self?.loginError = message + "\n" + url.absoluteString
                        self?.loginStage = "Apple account verification required"
                    }
                    return .cancel
                }
            )

            guard !isAuthenticationCancellationRequested else {
                throw CancellationError()
            }

            loginStage = "Loading Apple developer teams"
            logging(text: "Successfully signed in")

            let teams = try await fetchTeams(for: account, session: session)
            // Cache only a completed, verified Apple session; no OTP or 2FA code.
            try Keychain.shared.saveAppleSession(appleID: account.appleID, dsid: session.dsid, authToken: session.authToken)
            DataManager.shared.model.account = account
            DataManager.shared.model.session = session
            Keychain.shared.appleIDEmailAddress = account.appleID
            Keychain.shared.appleIDPassword = password
            logging(text: "Successfully fetched teams and saved login securely")
            availableTeams = teams
            loginStage = "Sign-in complete"
            appleID = ""
            password = ""
            return true
        } catch {
            if isAuthenticationCancellationRequested {
                throw CancellationError()
            }
            loginStage = "Apple authentication failed"
            logging(text: "Authentication error: \(error.localizedDescription)")
            throw error
        }
    }

    struct DeliveryChoice: Identifiable {
        let id: String
        let label: String
        let mode: SideSign.TwoFactorDeliveryMode
        let phoneID: String?
    }

    func submitDeliveryChoice() {
        guard choosingDelivery,
              let choice = verificationChoices.first(where: { $0.id == selectedDeliveryChoice }),
              let completion = sideSignContinuation else { return }
        sideSignContinuation = nil
        choosingDelivery = false
        loginStage = "Requesting Apple verification code"
        switch choice.mode {
        case .trustedDevice:
            completion.resume(returning: .requestTrustedDevice)
        case .sms:
            completion.resume(returning: .requestSMS(phoneID: choice.phoneID ?? "1"))
        case .voice:
            completion.resume(returning: .requestVoice(phoneID: choice.phoneID ?? "1"))
        }
    }

    private func requestSideStoreVerification(_ request: SideSign.TwoFactorRequest) async -> SideSign.TwoFactorResponse {
        if isAuthenticationCancellationRequested { return .cancel }
        // Apple may present a second challenge after a rejected or expired code.
        // Reset this flag so the verification field and Submit Code re-enable.
        isVerificationCodeSubmitting = false
        verificationCode = ""
        loginError = request.error
        logs.append("Received an Apple 2FA challenge; awaiting user response (secrets redacted)\n")
        switch request {
        case .selectDeliveryMethod(let preferredMode, let phones):
            var choices = [DeliveryChoice(id: "trusted", label: "Trusted Apple device", mode: .trustedDevice, phoneID: nil)]
            for phone in phones {
                choices.append(DeliveryChoice(id: "sms-" + phone.id, label: "SMS to " + phone.number, mode: .sms, phoneID: phone.id))
                choices.append(DeliveryChoice(id: "voice-" + phone.id, label: "Call " + phone.number, mode: .voice, phoneID: phone.id))
            }
            if phones.isEmpty {
                choices.append(DeliveryChoice(id: "sms-1", label: "SMS to trusted number", mode: .sms, phoneID: "1"))
            }
            verificationChoices = choices
            selectedDeliveryChoice = choices.first(where: { $0.mode == preferredMode })?.id ?? choices[0].id
            choosingDelivery = true
            needVerificationCode = false
            loginStage = "Choose how to receive your code"
        case .trustedDevice(let error):
            verificationMessage = error ?? "Enter the code on your trusted device."
            needVerificationCode = true
            choosingDelivery = false
            loginStage = "Enter trusted-device verification code"
        case .sms(_, _, let error):
            verificationMessage = error ?? "Enter the SMS verification code."
            needVerificationCode = true
            choosingDelivery = false
            loginStage = "Enter SMS verification code"
        case .voice(_, _, let error):
            verificationMessage = error ?? "Enter the code from the verification call."
            needVerificationCode = true
            choosingDelivery = false
            loginStage = "Enter voice verification code"
        }
        return await withCheckedContinuation { continuation in
            sideSignContinuation = continuation
        }
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        guard !isAuthenticationCancellationRequested else {
            handler(nil)
            return
        }

        verificationCodeHandler = handler
        verificationCode = ""
        loginStage = "Enter the Apple verification code"
        needVerificationCode = true
        isVerificationCodeSubmitting = false
    }
    
    func fetchTeams(for account: StosSign_Common.Account, session: AppleAPISession) async throws -> [StosSign_Common.Team]
    {

        let fetchedTeams = try await AppleAPI.shared.fetchTeamsForAccount(account: account, session: session)
        guard !fetchedTeams.isEmpty else {
            throw "Unable to Fetch Team!"
        }
        
        return fetchedTeams
    }
}
