import XCTest
@testable import LocalAuthenticator

@MainActor
final class AppUnlockStateTests: XCTestCase {
    func testDoesNotCreateAccountStoreBeforeUnlock() {
        var makeAccountStoreCallCount = 0
        let state = AppUnlockState { _ in
            makeAccountStoreCallCount += 1
            return AccountStore(keychain: FakeAccountSecureStore(), userDefaults: FakeAccountIDStore())
        }

        XCTAssertNil(state.accountStore)
        XCTAssertEqual(makeAccountStoreCallCount, 0)
    }

    func testLockClearsAccountStoreAndAllowsUnlockAgain() throws {
        let accountID = UUID()
        let account = OTPAccount(
            id: accountID,
            issuer: "Example",
            accountName: "alice@example.com",
            secretBase32: "JBSWY3DPEHPK3PXP"
        )
        let keychain = FakeAccountSecureStore(readResults: [accountID: .success(account)])
        let idStore = FakeAccountIDStore(ids: [accountID.uuidString])
        var makeAccountStoreCallCount = 0
        let state = AppUnlockState { _ in
            makeAccountStoreCallCount += 1
            return AccountStore(keychain: keychain, userDefaults: idStore)
        }

        state.unlock()
        let unlockedStore = try XCTUnwrap(state.accountStore)
        XCTAssertEqual(unlockedStore.accounts, [account])

        state.lock()

        XCTAssertNil(state.accountStore)
        XCTAssertTrue(unlockedStore.accounts.isEmpty)

        state.unlock()

        XCTAssertNotNil(state.accountStore)
        XCTAssertEqual(makeAccountStoreCallCount, 2)
    }
}
