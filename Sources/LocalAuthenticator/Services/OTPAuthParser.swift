import Foundation

enum OTPAuthParserError: Error, LocalizedError {
    case invalidURL
    case unsupportedType
    case missingSecret
    case unsupportedAlgorithm(String)
    case invalidDigits(String)
    case invalidPeriod(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Le QR code n'est pas une URI otpauth valide."
        case .unsupportedType:
            return "Seuls les comptes otpauth://totp sont supportés pour l'instant."
        case .missingSecret:
            return "Le QR code ne contient pas de secret."
        case .unsupportedAlgorithm(let algorithm):
            return "L'algorithme TOTP \(algorithm) n'est pas supporté."
        case .invalidDigits(let value):
            return "Le paramètre digits n'est pas un entier valide : \(value)."
        case .invalidPeriod(let value):
            return "Le paramètre period n'est pas un entier valide : \(value)."
        }
    }
}

struct OTPAuthParser {
    static func parse(_ rawValue: String) throws -> OTPAccount {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let url = URL(string: trimmedValue),
            url.scheme?.lowercased() == "otpauth"
        else {
            throw OTPAuthParserError.invalidURL
        }

        guard url.host?.lowercased() == "totp" else {
            throw OTPAuthParserError.unsupportedType
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OTPAuthParserError.invalidURL
        }

        let queryItems = components.queryItems ?? []

        func queryItem(_ name: String) -> URLQueryItem? {
            queryItems.first { $0.name.lowercased() == name.lowercased() }
        }

        func queryValue(_ name: String) -> String? {
            queryItem(name)?.value
        }

        func integerQueryValue(_ name: String, defaultValue: Int) throws -> Int {
            guard let item = queryItem(name) else {
                return defaultValue
            }

            guard let rawValue = item.value, let value = Int(rawValue) else {
                if name == "digits" {
                    throw OTPAuthParserError.invalidDigits(item.value ?? "")
                }

                throw OTPAuthParserError.invalidPeriod(item.value ?? "")
            }

            return value
        }

        guard let secret = queryValue("secret"), !secret.isEmpty else {
            throw OTPAuthParserError.missingSecret
        }

        let label = components.percentEncodedPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let labelParts = label
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .map(String.init)
        let issuerFromQuery = queryValue("issuer")
        let issuerFromLabel = labelParts.first?.removingPercentEncoding ?? labelParts.first
        let accountNameFromLabel: String
        if labelParts.count > 1 {
            accountNameFromLabel = labelParts[1].removingPercentEncoding ?? labelParts[1]
        } else {
            accountNameFromLabel = label.removingPercentEncoding ?? label
        }
        let issuer = issuerFromQuery ?? (labelParts.count > 1 ? issuerFromLabel : nil) ?? "Sans nom"
        let accountName = accountNameFromLabel

        let algorithm: OTPAlgorithm
        if let algorithmRaw = queryValue("algorithm")?.uppercased() {
            guard let parsedAlgorithm = OTPAlgorithm(rawValue: algorithmRaw) else {
                throw OTPAuthParserError.unsupportedAlgorithm(algorithmRaw)
            }

            algorithm = parsedAlgorithm
        } else {
            algorithm = .sha1
        }

        let digits = try integerQueryValue("digits", defaultValue: 6)
        let period = try integerQueryValue("period", defaultValue: 30)

        return OTPAccount(
            issuer: issuer.isEmpty ? "Sans nom" : issuer,
            accountName: accountName.isEmpty ? issuer : accountName,
            secretBase32: secret,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }
}
