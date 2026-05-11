import Foundation
import Combine

protocol AccountSecureStoring {
    func save(_ account: OTPAccount) throws
    func read(id: UUID) throws -> OTPAccount
    func migrateToCurrentProtection(_ account: OTPAccount) throws
    func delete(id: UUID) throws
}

protocol AccountIDStoring: AnyObject {
    func stringArray(forKey defaultName: String) -> [String]?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: AccountIDStoring {}

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [OTPAccount] = []
    @Published var lastError: String?

    private let keychain: any AccountSecureStoring
    private let userDefaults: any AccountIDStoring
    private let accountIDsKey = "LocalAuthenticator.accountIDs"

    init(
        keychain: any AccountSecureStoring = KeychainStore(),
        userDefaults: any AccountIDStoring = UserDefaults.standard
    ) {
        self.keychain = keychain
        self.userDefaults = userDefaults

        load()
    }

    func load() {
        let ids = storedIDs()
        var loadedAccounts: [OTPAccount] = []
        var retainedIDs: [UUID] = []
        lastError = nil

        for id in ids {
            do {
                let account = try keychain.read(id: id)
                loadedAccounts.append(account)
                retainedIDs.append(id)

                do {
                    try keychain.migrateToCurrentProtection(account)
                } catch {
                    lastError = error.localizedDescription
                }
            } catch {
                guard !isMissingKeychainItem(error) else {
                    continue
                }

                retainedIDs.append(id)
                lastError = error.localizedDescription
            }
        }

        accounts = loadedAccounts.sorted { lhs, rhs in
            if lhs.issuer == rhs.issuer {
                return lhs.accountName.localizedCaseInsensitiveCompare(rhs.accountName) == .orderedAscending
            }
            return lhs.issuer.localizedCaseInsensitiveCompare(rhs.issuer) == .orderedAscending
        }

        if retainedIDs != ids {
            saveIDs(retainedIDs)
        }
    }

    func add(_ account: OTPAccount) {
        do {
            let validatedAccount = try AccountValidator.validate(account)
            _ = try TOTPGenerator.generate(
                secretBase32: validatedAccount.secretBase32,
                period: validatedAccount.period,
                digits: validatedAccount.digits,
                algorithm: validatedAccount.algorithm
            )

            try keychain.save(validatedAccount)
            var ids = storedIDs()
            if !ids.contains(validatedAccount.id) {
                ids.append(validatedAccount.id)
            }
            saveIDs(ids)
            lastError = nil
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ account: OTPAccount) {
        do {
            try keychain.delete(id: account.id)
            let ids = storedIDs().filter { $0 != account.id }
            saveIDs(ids)
            lastError = nil
            load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clear() {
        accounts = []
        lastError = nil
    }

    private func storedIDs() -> [UUID] {
        let strings = userDefaults.stringArray(forKey: accountIDsKey) ?? []
        return strings.compactMap(UUID.init(uuidString:))
    }

    private func saveIDs(_ ids: [UUID]) {
        userDefaults.set(ids.map(\.uuidString), forKey: accountIDsKey)
    }

    private func isMissingKeychainItem(_ error: Error) -> Bool {
        guard case KeychainStoreError.readFailed(let status) = error else {
            return false
        }

        return status == errSecItemNotFound
    }
}
