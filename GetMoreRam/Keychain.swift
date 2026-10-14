//
//  Keychain.swift
//  AltStore
//
//  Created by Riley Testut on 6/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import Security

struct SavedAppleSession: Codable {
    let appleID: String
    let dsid: String
    let authToken: String
    var selectedTeamID: String?
}

@propertyWrapper
public struct KeychainItem<Value>
{
    public let key: String
    
    public var wrappedValue: Value? {
        get {
            switch Value.self
            {
            case is Data.Type: return Keychain.shared.keychain.data(for: self.key) as? Value
            case is String.Type: return Keychain.shared.keychain.string(for: self.key) as? Value
            default: return nil
            }
        }
        set {
            switch Value.self
            {
            case is Data.Type: Keychain.shared.keychain.set(newValue as? Data, for: self.key)
            case is String.Type: Keychain.shared.keychain.set(newValue as? String, for: self.key)
            default: break
            }
        }
    }
    
    public init(key: String)
    {
        self.key = key
    }
}

public class Keychain
{
    public static let shared = Keychain()
    
    fileprivate let keychain = SystemKeychain(service: Bundle.main.bundleIdentifier!)
    
    @KeychainItem(key: "appleIDEmailAddress")
    public var appleIDEmailAddress: String?
    
    @KeychainItem(key: "appleIDPassword")
    public var appleIDPassword: String?
    
    @KeychainItem(key: "signingCertificatePrivateKey")
    public var signingCertificatePrivateKey: Data?
    
    @KeychainItem(key: "signingCertificateSerialNumber")
    public var signingCertificateSerialNumber: String?
    
    @KeychainItem(key: "signingCertificate")
    public var signingCertificate: Data?
    
    @KeychainItem(key: "signingCertificatePassword")
    public var signingCertificatePassword: String?
    
    @KeychainItem(key: "patreonAccessToken")
    public var patreonAccessToken: String?
    
    @KeychainItem(key: "patreonRefreshToken")
    public var patreonRefreshToken: String?
    
    @KeychainItem(key: "patreonCreatorAccessToken")
    public var patreonCreatorAccessToken: String?
    
    @KeychainItem(key: "patreonAccountID")
    public var patreonAccountID: String?
    
    @KeychainItem(key: "identifier")
    public var identifier: String?
    
    @KeychainItem(key: "adiPb")
    public var adiPb: String?
    
    private init()
    {
    }

    // Device-only Keychain; auth tokens must not be written to UserDefaults or iCloud.
    // Anisette OTP values are deliberately NOT persisted in this record.
    var savedAppleSession: SavedAppleSession? {
        guard let data = keychain.deviceOnlyData(for: "savedAppleSession.v1") else { return nil }
        return try? JSONDecoder().decode(SavedAppleSession.self, from: data)
    }

    func saveAppleSession(appleID: String, dsid: String, authToken: String, teamID: String? = nil) throws {
        guard !appleID.isEmpty, !dsid.isEmpty, !authToken.isEmpty else {
            throw "Missing Apple authentication credentials; refusing to cache an incomplete session."
        }
        let record = SavedAppleSession(appleID: appleID, dsid: dsid, authToken: authToken, selectedTeamID: teamID)
        let data = try JSONEncoder().encode(record)
        try keychain.setDeviceOnly(data, for: "savedAppleSession.v1")
    }

    func saveSelectedTeam(_ teamID: String) throws {
        guard var saved = savedAppleSession else { return }
        saved.selectedTeamID = teamID
        try keychain.setDeviceOnly(JSONEncoder().encode(saved), for: "savedAppleSession.v1")
    }

    func clearSavedAppleSession() {
        try? keychain.setDeviceOnly(nil, for: "savedAppleSession.v1")
    }
    
    public func reset()
    {
        self.appleIDEmailAddress = nil
        self.appleIDPassword = nil
        self.clearSavedAppleSession()
        self.signingCertificatePrivateKey = nil
        self.signingCertificateSerialNumber = nil
    }
}

fileprivate struct SystemKeychain {
    let service: String

    // Separate local-only Keychain namespace, protected until the user has unlocked once.
    private func deviceOnlyQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service + ".deviceOnly",
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    func deviceOnlyData(for key: String) -> Data? {
        var query = deviceOnlyQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func setDeviceOnly(_ data: Data?, for key: String) throws {
        let query = deviceOnlyQuery(for: key)
        guard let data else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            return
        }

        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            for (key, value) in attrs { insert[key] = value }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
    
    func data(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    func string(for key: String) -> String? {
        guard let data = data(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func set(_ string: String?, for key: String) {
        set(string?.data(using: .utf8), for: key)
    }
    
    func set(_ data: Data?, for key: String) {
        deleteItem(for: key)
        
        guard let data else { return }
        
        var attributes = baseQuery(for: key)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }
    
    private func deleteItem(for key: String) {
        var query = baseQuery(for: key)
        query[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        SecItemDelete(query as CFDictionary)
    }
    
    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any
        ]
    }
}
