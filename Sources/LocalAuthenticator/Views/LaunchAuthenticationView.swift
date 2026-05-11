import LocalAuthentication
import SwiftUI

struct LaunchAuthenticationView: View {
    let isSceneActive: Bool
    let onUnlocked: (LAContext) -> Void

    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    @State private var didStartAuthentication = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            VStack(spacing: 22) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 58))
                    .foregroundStyle(.primary.opacity(0.78))
                    .frame(width: 96, height: 96)
                    .liquidGlassPanel(cornerRadius: 32, material: .thinMaterial, shadowRadius: 14, shadowOpacity: 0.10)

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
                        .buttonStyle(.liquidGlassProminent)
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
            .padding(34)
            .frame(maxWidth: 440)
            .liquidGlassPanel(cornerRadius: 34, material: .regularMaterial, shadowRadius: 24, shadowOpacity: 0.14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
