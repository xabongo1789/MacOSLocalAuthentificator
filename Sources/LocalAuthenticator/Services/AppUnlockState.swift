import Combine
import Foundation
import LocalAuthentication

@MainActor
final class AppUnlockState: ObservableObject {
    @Published private(set) var accountStore: AccountStore?

    private let makeAccountStore: @MainActor (LAContext?) -> AccountStore

    init(makeAccountStore: @escaping @MainActor (LAContext?) -> AccountStore = {
        AccountStore(keychain: KeychainStore(authenticationContext: $0))
    }) {
        self.makeAccountStore = makeAccountStore
    }

    func unlock(authenticationContext: LAContext? = nil) {
        guard accountStore == nil else {
            return
        }

        accountStore = makeAccountStore(authenticationContext)
    }

    func lock() {
        accountStore?.clear()
        accountStore = nil
    }
}
