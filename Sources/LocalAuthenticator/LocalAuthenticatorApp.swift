import SwiftUI

@main
struct LocalAuthenticatorApp: App {
    @StateObject private var accountStore = AccountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountStore)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
