import LocalAuthentication
import SwiftUI

struct LaunchAuthenticationView: View {
    let isSceneActive: Bool
    let onUnlocked: (LAContext) -> Void

    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var didStartAuthentication = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield")
                .font(.system(size: 58))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Local Authenticator")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authentification requise")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                if isAuthenticating {
                    ProgressView("Vérification…")
                        .controlSize(.small)
                } else {
                    Button {
                        authenticate()
                    } label: {
                        Label("Déverrouiller", systemImage: "touchid")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
            }
            .frame(minHeight: 78)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear(perform: startAuthenticationOnce)
        .onChange(of: isSceneActive) { isActive in
            guard isActive else {
                return
            }

            startAuthenticationOnce()
        }
    }

    private func startAuthenticationOnce() {
        guard isSceneActive, !didStartAuthentication else {
            return
        }

        didStartAuthentication = true
        authenticate()
    }

    private func authenticate() {
        guard isSceneActive, !isAuthenticating else {
            return
        }

        isAuthenticating = true
        errorMessage = nil

        Task {
            do {
                let authenticationContext = try await LaunchAuthenticator().authenticate()
                await MainActor.run {
                    isAuthenticating = false
                    onUnlocked(authenticationContext)
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
