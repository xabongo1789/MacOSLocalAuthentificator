import Foundation
import LocalAuthentication

struct LaunchAuthenticator {
    func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        context.localizedFallbackTitle = "Utiliser le mot de passe"

        var evaluationError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError) else {
            throw LaunchAuthenticationError.unavailable(Self.message(for: evaluationError))
        }

        do {
            let isAuthenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Déverrouiller l’accès aux codes TOTP."
            )

            guard isAuthenticated else {
                throw LaunchAuthenticationError.failed("Authentification refusée.")
            }
        } catch {
            throw LaunchAuthenticationError.failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error?) -> String {
        guard let error else {
            return "L’authentification locale n’est pas disponible."
        }

        let nsError = error as NSError
        guard nsError.domain == LAError.errorDomain, let code = LAError.Code(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .authenticationFailed:
            return "L’authentification a échoué."
        case .userCancel:
            return "Authentification annulée."
        case .userFallback:
            return "Utilisez le mot de passe macOS pour continuer."
        case .systemCancel:
            return "Authentification interrompue par macOS."
        case .passcodeNotSet:
            return "Aucun mot de passe macOS n’est configuré."
        case .biometryNotAvailable:
            return "Touch ID n’est pas disponible sur ce Mac."
        case .biometryNotEnrolled:
            return "Aucune empreinte Touch ID n’est configurée."
        case .biometryLockout:
            return "Touch ID est verrouillé. Utilisez le mot de passe macOS."
        case .appCancel:
            return "Authentification interrompue par l’app."
        case .invalidContext:
            return "La session d’authentification n’est plus valide."
        case .notInteractive:
            return "macOS ne peut pas afficher la demande d’authentification."
        case .watchNotAvailable:
            return "L’Apple Watch n’est pas disponible pour l’authentification."
        default:
            return error.localizedDescription
        }
    }
}

enum LaunchAuthenticationError: LocalizedError {
    case unavailable(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .failed(let message):
            return message
        }
    }
}
