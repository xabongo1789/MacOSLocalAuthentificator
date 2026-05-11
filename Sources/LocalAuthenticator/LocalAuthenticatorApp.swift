import SwiftUI

@main
struct LocalAuthenticatorApp: App {
    @State private var isUnlocked = false
    @StateObject private var accountStore = AccountStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if isUnlocked {
                    ContentView()
                        .environmentObject(accountStore)
                } else {
                    LaunchAuthenticationView {
                        isUnlocked = true
                    }
                }
            }
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
