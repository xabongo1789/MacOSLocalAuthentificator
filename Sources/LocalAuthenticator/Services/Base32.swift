import Foundation

enum Base32Error: Error, LocalizedError {
    case invalidCharacter(Character)
    case emptySecret

    var errorDescription: String? {
        switch self {
        case .invalidCharacter(let character):
            return "Caractère Base32 invalide : \(character)"
        case .emptySecret:
            return "La clé secrète est vide."
        }
    }
}

enum Base32 {
    static func decode(_ input: String) throws -> Data {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var lookup: [Character: Int] = [:]

        for (index, character) in alphabet.enumerated() {
            lookup[character] = index
        }

        let cleaned = input
            .uppercased()
            .filter { !$0.isWhitespace && $0 != "=" && $0 != "-" }

        guard !cleaned.isEmpty else {
            throw Base32Error.emptySecret
        }

        var buffer = 0
        var bitsLeft = 0
        var result = Data()

        for character in cleaned {
            guard let value = lookup[character] else {
                throw Base32Error.invalidCharacter(character)
            }

            buffer = (buffer << 5) | value
            bitsLeft += 5

            if bitsLeft >= 8 {
                let byte = UInt8((buffer >> (bitsLeft - 8)) & 0xff)
                result.append(byte)
                bitsLeft -= 8
                buffer &= (1 << bitsLeft) - 1
            }
        }

        return result
    }
}
