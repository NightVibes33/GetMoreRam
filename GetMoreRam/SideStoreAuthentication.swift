//
//  SideStoreAuthentication.swift
//  GetMoreRam
//
//  Use the SAME SideSign authentication implementation pinned by SideStore
//  nightly. StosSign remains only for GetMoreRam's existing capability APIs.
//

import Foundation
import SideSign
import StosSign_API
import StosSign_Common

enum SideStoreAuthentication {
    static let clientInfo =
        "<Pixel 7> <Android;14;UQ1A.240205.002> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    // ODA provisions using Android AuthKit; use that same profile at Apple
    // sign-in unless the user explicitly selected another identity.
    static let androidUserAgent = "AuthKit/1 (Android; Android 14) (com.apple.akd/1.0)"
    // Keep the existing remote V3 default unchanged for compatibility.
    static let remoteDefaultUserAgent = "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"

    static func authenticate(
        appleID: String,
        password: String,
        anisetteData: StosSign_Common.AnisetteData,
        verificationHandler: @escaping SideSign.DeveloperPortal.VerificationHandler,
        accountRepairHandler: @escaping SideSign.DeveloperPortal.AccountRepairHandler
    ) async throws -> (StosSign_Common.Account, StosSign_API.AppleAPISession) {
        let preferences = UserDefaults.standard
        let configuredInfo = preferences.string(forKey: "CustomClientInfo")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredAgent = preferences.string(forKey: "CustomUserAgent")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveInfo = (configuredInfo?.isEmpty == false) ? configuredInfo! : clientInfo
        let onDeviceAnisette = preferences.object(forKey: "UseOnDeviceAnisette") == nil
            || preferences.bool(forKey: "UseOnDeviceAnisette")
        let defaultAgent = onDeviceAnisette ? androidUserAgent : remoteDefaultUserAgent
        let effectiveAgent = (configuredAgent?.isEmpty == false) ? configuredAgent! : defaultAgent

        var headers = SideSign.DeveloperPortal.shared.customHeaders
        headers.grandSlam.userAgent = effectiveAgent
        headers.appleAuth.userAgent = effectiveAgent
        SideSign.DeveloperPortal.shared.customHeaders = headers

        let sideAnisette = SideSign.AnisetteData(
            machineID: anisetteData.machineID,
            oneTimePassword: anisetteData.oneTimePassword,
            localUserID: anisetteData.localUserID,
            routingInfo: String(anisetteData.routingInfo),
            deviceID: anisetteData.deviceUniqueIdentifier,
            serialNumber: anisetteData.deviceSerialNumber,
            clientInfo: effectiveInfo,
            userAgent: effectiveAgent,
            clientTime: ISO8601DateFormatter().string(from: anisetteData.date),
            locale: anisetteData.locale.identifier,
            timeZone: anisetteData.timeZone.identifier
        )

        let result: SideSign.AuthSession
        do {
            result = try await SideSign.DeveloperPortal.shared.authenticate(
            appleID: appleID,
            password: password,
            anisetteData: sideAnisette,
            xcodeVersion: "26.0 (26A242)",
            machinePassword: nil,
            accountRepairHandler: accountRepairHandler,
            verificationHandler: verificationHandler
            )
        } catch SideSign.ServerError.invalidResponseFormat(let payload)
            where payload.localizedCaseInsensitiveContains("503 Service")
                || payload.localizedCaseInsensitiveContains("<title>503")
                || payload.localizedCaseInsensitiveContains("502 Bad Gateway")
                || payload.localizedCaseInsensitiveContains("504 Gateway") {
            // Some Apple 2FA routes still bypass the patched request dispatchers.
            // Do not display raw HTML from those endpoints to the user.
            throw NSError(
                domain: "GetMoreRam.AppleHTTP",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey:
                    "Apple authentication returned a temporary gateway error. The response was HTML, not Apple login data; your Anisette provider may still be working. Retry later."]
            )
        }

        // SideSign signs in with effectiveInfo, which may differ from the
        // ODA provider's defaults. Preserve that identity in the StosSign
        // session used for capability updates.
        let developerAnisette = StosSign_Common.AnisetteData(
            machineID: anisetteData.machineID,
            oneTimePassword: anisetteData.oneTimePassword,
            localUserID: anisetteData.localUserID,
            routingInfo: anisetteData.routingInfo,
            deviceUniqueIdentifier: anisetteData.deviceUniqueIdentifier,
            deviceSerialNumber: anisetteData.deviceSerialNumber,
            deviceDescription: effectiveInfo,
            date: anisetteData.date,
            locale: anisetteData.locale,
            timeZone: anisetteData.timeZone
        )
        let legacySession = StosSign_API.AppleAPISession(
            dsid: result.session.dsid,
            authToken: result.session.authToken,
            anisetteData: developerAnisette
        )
        let account = try await StosSign_API.AppleAPI.shared.fetchAccount(session: legacySession)
        return (account, legacySession)
    }
}
