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
    static let userAgent = "AuthKit/1 (Macintosh; OS X 26.6) (com.apple.akd/1.0)"

    static func authenticate(
        appleID: String,
        password: String,
        anisetteData: StosSign_Common.AnisetteData,
        verificationHandler: @escaping SideSign.DeveloperPortal.VerificationHandler,
        accountRepairHandler: @escaping SideSign.DeveloperPortal.AccountRepairHandler
    ) async throws -> (StosSign_Common.Account, StosSign_API.AppleAPISession) {
        var headers = SideSign.DeveloperPortal.shared.customHeaders
        headers.grandSlam.userAgent = userAgent
        headers.appleAuth.userAgent = userAgent
        SideSign.DeveloperPortal.shared.customHeaders = headers

        let sideAnisette = SideSign.AnisetteData(
            machineID: anisetteData.machineID,
            oneTimePassword: anisetteData.oneTimePassword,
            localUserID: anisetteData.localUserID,
            routingInfo: String(anisetteData.routingInfo),
            deviceID: anisetteData.deviceUniqueIdentifier,
            serialNumber: anisetteData.deviceSerialNumber,
            clientInfo: clientInfo,
            userAgent: userAgent,
            clientTime: ISO8601DateFormatter().string(from: anisetteData.date),
            locale: anisetteData.locale.identifier,
            timeZone: anisetteData.timeZone.identifier
        )

        let result = try await SideSign.DeveloperPortal.shared.authenticate(
            appleID: appleID,
            password: password,
            anisetteData: sideAnisette,
            xcodeVersion: "26.0 (26A242)",
            machinePassword: nil,
            accountRepairHandler: accountRepairHandler,
            verificationHandler: verificationHandler
        )

        let legacySession = StosSign_API.AppleAPISession(
            dsid: result.session.dsid,
            authToken: result.session.authToken,
            anisetteData: anisetteData
        )
        let account = try await StosSign_API.AppleAPI.shared.fetchAccount(session: legacySession)
        return (account, legacySession)
    }
}
