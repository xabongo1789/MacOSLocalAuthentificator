import AppKit
import SwiftUI

@main
struct LocalAuthenticatorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var unlockState = AppUnlockState()

    var body: some Scene {
        WindowGroup {
            Group {
                if let accountStore = unlockState.accountStore {
                    ContentView()
                        .environmentObject(accountStore)
                } else {
                    LaunchAuthenticationView(isSceneActive: scenePhase == .active) { authenticationContext in
                        guard scenePhase == .active else {
                            unlockState.lock()
                            return
                        }

                        unlockState.unlock(authenticationContext: authenticationContext)
                    }
                }
            }
                .frame(minWidth: 720, minHeight: 480)
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase != .active else {
                        return
                    }

                    unlockState.lock()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
                    unlockState.lock()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in
                    unlockState.lock()
                }
        }
    }
}
