import Security
import XCTest
@testable import LocalAuthenticator

@MainActor
final class AccountStoreTests: XCTestCase {
    func testAddSavesAccountIDAndUpdatesListWithoutImmediateReload() throws {
        let account = OTPAccount(
            issuer: "Example",
            accountName: "alice@example.com",
            secretBase32: "jbsw y3dp-ehpk3pxp"
        )
        let validatedAccount = try AccountValidator.validate(account)
        let keychain = FakeAccountSecureStore()
        let idStore = FakeAccountIDStore()
        let store = AccountStore(keychain: keychain, userDefaults: idStore)

        store.add(account)

        XCTAssertEqual(keychain.savedAccounts, [validatedAccount])
        XCTAssertEqual(keychain.migratedAccounts, [])
        XCTAssertEqual(store.accounts, [validatedAccount])
        XCTAssertEqual(idStore.strings, [validatedAccount.id.uuidString])
        XCTAssertNil(store.lastError)
    }

    func testLoadRemovesOnlyConfirmedMissingKeychainItems() {
        let validID = UUID()
        let transientFailureID = UUID()
        let decodeFailureID = UUID()
        let missingID = UUID()
        let account = OTPAccount(
            id: validID,
            issuer: "Example",
            accountName: "alice@example.com",
            secretBase32: "JBSWY3DPEHPK3PXP"
        )
        let keychain = FakeAccountSecureStore(readResults: [
            validID: .success(account),
            transientFailureID: .failure(KeychainStoreError.readFailed(errSecInteractionNotAllowed)),
            decodeFailureID: .failure(KeychainStoreError.decodeFailed),
            missingID: .failure(KeychainStoreError.readFailed(errSecItemNotFound))
        ])
        let idStore = FakeAccountIDStore(ids: [
            validID.uuidString,
            transientFailureID.uuidString,
            decodeFailureID.uuidString,
            missingID.uuidString
        ])

        let store = AccountStore(keychain: keychain, userDefaults: idStore)

        XCTAssertEqual(store.accounts, [account])
        XCTAssertEqual(keychain.migratedAccounts, [account])
        XCTAssertEqual(idStore.strings, [
            validID.uuidString,
            transientFailureID.uuidString,
            decodeFailureID.uuidString
        ])
    }

    func testLoadKeepsAccountWhenProtectionMigrationFails() {
        let accountID = UUID()
        let account = OTPAccount(
            id: accountID,
            issuer: "Example",
            accountName: "alice@example.com",
            secretBase32: "JBSWY3DPEHPK3PXP"
        )
        let keychain = FakeAccountSecureStore(
            readResults: [accountID: .success(account)],
            migrationResults: [accountID: .failure(KeychainStoreError.saveFailed(errSecInteractionNotAllowed))]
        )
        let idStore = FakeAccountIDStore(ids: [accountID.uuidString])

        let store = AccountStore(keychain: keychain, userDefaults: idStore)

        XCTAssertEqual(store.accounts, [account])
        XCTAssertEqual(idStore.strings, [accountID.uuidString])
        XCTAssertEqual(keychain.migratedAccounts, [account])
        XCTAssertEqual(store.lastError, KeychainStoreError.saveFailed(errSecInteractionNotAllowed).localizedDescription)
    }
}
