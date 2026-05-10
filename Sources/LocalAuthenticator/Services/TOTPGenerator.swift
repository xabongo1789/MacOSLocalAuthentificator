import Foundation
import CryptoKit

enum TOTPError: Error, LocalizedError {
    case unsupportedDigits
    case invalidPeriod

    var errorDescription: String? {
        switch self {
        case .unsupportedDigits:
            return "Le nombre de chiffres doit être compris entre 6 et 8."
        case .invalidPeriod:
            return "La période doit être supérieure à 0."
        }
    }
}

final class TOTPGenerator {
    static func generate(
        secretBase32: String,
        date: Date = Date(),
        period: Int = 30,
        digits: Int = 6,
        algorithm: OTPAlgorithm = .sha1
    ) throws -> String {
        guard (6...8).contains(digits) else {
            throw TOTPError.unsupportedDigits
        }

        guard period > 0 else {
            throw TOTPError.invalidPeriod
        }

        let keyData = try Base32.decode(secretBase32)
        let counter = UInt64(date.timeIntervalSince1970 / Double(period))
        var counterBigEndian = counter.bigEndian
        let counterData = withUnsafeBytes(of: &counterBigEndian) { Data($0) }
        let key = SymmetricKey(data: keyData)

        let hash: [UInt8]
        switch algorithm {
        case .sha1:
            hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256:
            hash = Array(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            hash = Array(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        let offset = Int(hash[hash.count - 1] & 0x0f)
        let binary =
            (UInt32(hash[offset] & 0x7f) << 24) |
            (UInt32(hash[offset + 1] & 0xff) << 16) |
            (UInt32(hash[offset + 2] & 0xff) << 8) |
            UInt32(hash[offset + 3] & 0xff)

        let divisor = UInt32(pow(10.0, Double(digits)))
        let otp = binary % divisor
        return String(format: "%0*u", digits, otp)
    }
}
