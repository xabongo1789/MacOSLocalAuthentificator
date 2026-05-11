import Foundation
import LocalAuthentication
import Security

enum KeychainStoreError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodeFailed
    case accessControlCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Échec de sauvegarde Keychain : \(Self.statusDescription(status))"
        case .readFailed(let status):
            return "Échec de lecture Keychain : \(Self.statusDescription(status))"
        case .deleteFailed(let status):
            return "Échec de suppression Keychain : \(Self.statusDescription(status))"
        case .decodeFailed:
            return "Impossible de décoder les données Keychain."
        case .accessControlCreationFailed(let message):
            return "Impossible de protéger l'élément Keychain : \(message)"
        }
    }

    private static func statusDescription(_ status: OSStatus) -> String {
        guard let message = SecCopyErrorMessageString(status, nil) as String? else {
            return "\(status)"
        }

        return "\(message) (\(status))"
    }
}

final class KeychainStore: AccountSecureStoring {
    private let service = "com.local.LocalAuthenticator"
    private let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    private let operationPrompt = "Déverrouiller l’accès aux codes TOTP."
    private let authenticationContext: LAContext?

    init(authenticationContext: LAContext? = nil) {
        self.authenticationContext = authenticationContext
    }

    func save(_ account: OTPAccount) throws {
        let data = try JSONEncoder().encode(account)
        let key = account.id.uuidString
        let accessControl = try makeAccessControl()

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessControl as String: accessControl,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        guard addStatus == errSecDuplicateItem else {
            throw KeychainStoreError.saveFailed(addStatus)
        }

        try updateExistingItem(key: key, data: data)
    }

    private func updateExistingItem(
        key: String,
        data: Data,
        accessControl: SecAccessControl? = nil
    ) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        if let authenticationContext {
            authenticationContext.localizedReason = operationPrompt
            query[kSecUseAuthenticationContext as String] = authenticationContext
        }

        var attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        if let accessControl {
            attributes[kSecAttrAccessControl as String] = accessControl
        }

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainStoreError.saveFailed(status)
        }
    }

    func read(id: UUID) throws -> OTPAccount {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let context = authenticationContext ?? LAContext()
        context.localizedReason = operationPrompt
        query[kSecUseAuthenticationContext as String] = context

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainStoreError.readFailed(status)
        }

        guard let data = result as? Data else {
            throw KeychainStoreError.decodeFailed
        }

        return try JSONDecoder().decode(OTPAccount.self, from: data)
    }

    func migrateToCurrentProtection(_ account: OTPAccount) throws {
        guard try requiresProtectionMigration(id: account.id) else {
            return
        }

        let data = try JSONEncoder().encode(account)
        try updateExistingItem(
            key: account.id.uuidString,
            data: data,
            accessControl: makeAccessControl()
        )
    }

    func delete(id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.deleteFailed(status)
        }
    }

    private func makeAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            accessibility,
            .userPresence,
            &error
        ) else {
            let message = error?.takeRetainedValue().localizedDescription ?? "raison inconnue"
            throw KeychainStoreError.accessControlCreationFailed(message)
        }

        return accessControl
    }

    private func requiresProtectionMigration(id: UUID) throws -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let authenticationContext {
            authenticationContext.localizedReason = operationPrompt
            query[kSecUseAuthenticationContext as String] = authenticationContext
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainStoreError.readFailed(status)
        }

        guard let attributes = result as? [String: Any] else {
            return true
        }

        let accessibility = attributes[kSecAttrAccessible as String] as? String
        let hasCurrentAccessibility = accessibility == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        let hasAccessControl = attributes[kSecAttrAccessControl as String] != nil

        return !hasCurrentAccessibility || !hasAccessControl
    }
}
