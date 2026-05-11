import Foundation
import Security
@testable import LocalAuthenticator

final class FakeAccountSecureStore: AccountSecureStoring {
    var readResults: [UUID: Result<OTPAccount, Error>]
    var migrationResults: [UUID: Result<Void, Error>]
    private(set) var savedAccounts: [OTPAccount] = []
    private(set) var migratedAccounts: [OTPAccount] = []
    private(set) var deletedIDs: [UUID] = []

    init(
        readResults: [UUID: Result<OTPAccount, Error>] = [:],
        migrationResults: [UUID: Result<Void, Error>] = [:]
    ) {
        self.readResults = readResults
        self.migrationResults = migrationResults
    }

    func save(_ account: OTPAccount) throws {
        savedAccounts.append(account)
        readResults[account.id] = .success(account)
    }

    func read(id: UUID) throws -> OTPAccount {
        guard let result = readResults[id] else {
            throw KeychainStoreError.readFailed(errSecItemNotFound)
        }

        return try result.get()
    }

    func migrateToCurrentProtection(_ account: OTPAccount) throws {
        migratedAccounts.append(account)

        if let result = migrationResults[account.id] {
            try result.get()
        }
    }

    func delete(id: UUID) throws {
        deletedIDs.append(id)
        readResults[id] = .failure(KeychainStoreError.readFailed(errSecItemNotFound))
    }
}

final class FakeAccountIDStore: AccountIDStoring {
    private(set) var savedValues: [[String]] = []
    var strings: [String]?

    init(ids: [String] = []) {
        strings = ids
    }

    func stringArray(forKey defaultName: String) -> [String]? {
        strings
    }

    func set(_ value: Any?, forKey defaultName: String) {
        strings = value as? [String]
        savedValues.append(strings ?? [])
    }
}
