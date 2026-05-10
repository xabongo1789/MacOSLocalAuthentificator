import Foundation

enum OTPAuthParserError: Error, LocalizedError {
    case invalidURL
    case unsupportedType
    case missingSecret

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Le QR code n'est pas une URI otpauth valide."
        case .unsupportedType:
            return "Seuls les comptes otpauth://totp sont supportés pour l'instant."
        case .missingSecret:
            return "Le QR code ne contient pas de secret."
        }
    }
}

struct OTPAuthParser {
    static func parse(_ rawValue: String) throws -> OTPAccount {
        guard
            let url = URL(string: rawValue),
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

        func queryValue(_ name: String) -> String? {
            queryItems.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }

        guard let secret = queryValue("secret"), !secret.isEmpty else {
            throw OTPAuthParserError.missingSecret
        }

        let label = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .removingPercentEncoding ?? ""

        let labelParts = label.split(separator: ":", maxSplits: 1).map(String.init)
        let issuerFromQuery = queryValue("issuer")?.removingPercentEncoding
        let issuer = issuerFromQuery ?? labelParts.first ?? "Sans nom"
        let accountName = labelParts.count > 1 ? labelParts[1] : label

        let algorithmRaw = queryValue("algorithm")?.uppercased() ?? OTPAlgorithm.sha1.rawValue
        let algorithm = OTPAlgorithm(rawValue: algorithmRaw) ?? .sha1
        let digits = Int(queryValue("digits") ?? "6") ?? 6
        let period = Int(queryValue("period") ?? "30") ?? 30

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
