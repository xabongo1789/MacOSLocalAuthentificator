import Foundation

enum Base32Error: Error, LocalizedError {
    case invalidCharacter(Character)
    case emptySecret
    case invalidPadding

    var errorDescription: String? {
        switch self {
        case .invalidCharacter(let character):
            return "Caractère Base32 invalide : \(character)"
        case .emptySecret:
            return "La clé secrète est vide."
        case .invalidPadding:
            return "La fin de la clé Base32 est invalide."
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

        guard ![1, 3, 6].contains(cleaned.count % 8) else {
            throw Base32Error.invalidPadding
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

        guard bitsLeft == 0 || buffer == 0 else {
            throw Base32Error.invalidPadding
        }

        guard !result.isEmpty else {
            throw Base32Error.emptySecret
        }

        return result
    }
}
