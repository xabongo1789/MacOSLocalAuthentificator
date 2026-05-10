import Foundation

enum AccountValidationError: Error, LocalizedError {
    case missingIssuer
    case missingAccountName
    case missingSecret
    case invalidSecret(String)
    case unsupportedDigits
    case invalidPeriod

    var errorDescription: String? {
        switch self {
        case .missingIssuer:
            return "Renseigne le nom du service."
        case .missingAccountName:
            return "Renseigne le nom du compte."
        case .missingSecret:
            return "Renseigne la clé secrète Base32."
        case .invalidSecret(let reason):
            return "La clé secrète Base32 n'est pas valide. \(reason)"
        case .unsupportedDigits:
            return "Le nombre de chiffres doit être compris entre 6 et 8."
        case .invalidPeriod:
            return "La période doit être supérieure à 0."
        }
    }
}

enum AccountValidator {
    static func makeManualAccount(
        issuer: String,
        accountName: String,
        secretBase32: String,
        algorithm: OTPAlgorithm,
        digits: Int,
        period: Int
    ) throws -> OTPAccount {
        try validate(
            OTPAccount(
                issuer: issuer,
                accountName: accountName,
                secretBase32: secretBase32,
                algorithm: algorithm,
                digits: digits,
                period: period
            )
        )
    }

    static func parseOTPAuthURI(_ rawValue: String) throws -> OTPAccount {
        try validate(OTPAuthParser.parse(rawValue))
    }

    static func validate(_ account: OTPAccount) throws -> OTPAccount {
        let issuer = account.issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let accountName = account.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = normalizedSecret(account.secretBase32)

        guard !issuer.isEmpty else {
            throw AccountValidationError.missingIssuer
        }

        guard !accountName.isEmpty else {
            throw AccountValidationError.missingAccountName
        }

        guard !secret.isEmpty else {
            throw AccountValidationError.missingSecret
        }

        guard (6...8).contains(account.digits) else {
            throw AccountValidationError.unsupportedDigits
        }

        guard account.period > 0 else {
            throw AccountValidationError.invalidPeriod
        }

        do {
            _ = try Base32.decode(secret)
        } catch Base32Error.emptySecret {
            throw AccountValidationError.missingSecret
        } catch {
            throw AccountValidationError.invalidSecret(error.localizedDescription)
        }

        return OTPAccount(
            id: account.id,
            issuer: issuer,
            accountName: accountName,
            secretBase32: secret,
            algorithm: account.algorithm,
            digits: account.digits,
            period: account.period
        )
    }

    static func normalizedSecret(_ input: String) -> String {
        input
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "=" && $0 != "-" }
    }
}
