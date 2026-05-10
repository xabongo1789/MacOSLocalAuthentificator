import Foundation
import Combine

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [OTPAccount] = []
    @Published var lastError: String?

    private let keychain = KeychainStore()
    private let userDefaults = UserDefaults.standard
    private let accountIDsKey = "LocalAuthenticator.accountIDs"

    init() {
        load()
    }

    func load() {
        let ids = storedIDs()
        var loadedAccounts: [OTPAccount] = []
        var validIDs: [UUID] = []

        for id in ids {
            do {
                let account = try keychain.read(id: id)
                loadedAccounts.append(account)
                validIDs.append(id)
            } catch {
                lastError = error.localizedDescription
            }
        }

        accounts = loadedAccounts.sorted { lhs, rhs in
            if lhs.issuer == rhs.issuer {
                return lhs.accountName.localizedCaseInsensitiveCompare(rhs.accountName) == .orderedAscending
            }
            return lhs.issuer.localizedCaseInsensitiveCompare(rhs.issuer) == .orderedAscending
        }

        saveIDs(validIDs)
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

    private func storedIDs() -> [UUID] {
        let strings = userDefaults.stringArray(forKey: accountIDsKey) ?? []
        return strings.compactMap(UUID.init(uuidString:))
    }

    private func saveIDs(_ ids: [UUID]) {
        userDefaults.set(ids.map(\.uuidString), forKey: accountIDsKey)
    }
}
