import Foundation
import Security

enum KeychainStoreError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Échec de sauvegarde Keychain : \(status)"
        case .readFailed(let status):
            return "Échec de lecture Keychain : \(status)"
        case .deleteFailed(let status):
            return "Échec de suppression Keychain : \(status)"
        case .decodeFailed:
            return "Impossible de décoder les données Keychain."
        }
    }
}

final class KeychainStore {
    private let service = "com.local.LocalAuthenticator"

    func save(_ account: OTPAccount) throws {
        let data = try JSONEncoder().encode(account)
        let key = account.id.uuidString

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.saveFailed(status)
        }
    }

    func read(id: UUID) throws -> OTPAccount {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

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

    func delete(id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.deleteFailed(status)
        }
    }
}
