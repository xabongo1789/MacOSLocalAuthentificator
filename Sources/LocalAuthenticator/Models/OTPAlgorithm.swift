import Foundation

enum OTPAlgorithm: String, Codable, CaseIterable, Identifiable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"

    var id: String { rawValue }
}
