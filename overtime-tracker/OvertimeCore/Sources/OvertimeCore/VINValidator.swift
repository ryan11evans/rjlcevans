import Foundation

/// ISO 3779 VIN check digit. Position 9 is the check character. Remainder 10 is `X`.
/// I, O, and Q are never legal. This does not contact NHTSA.
public enum VINValidator {
    public enum Status: Equatable, Sendable {
        case valid
        case wrongLength(Int)
        case illegalCharacter(Character)
        case badCheckDigit(expected: Character)
    }

    private static let weights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2]

    public static func normalize(_ vin: String) -> String {
        vin.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }

    public static func isValid(_ vin: String) -> Bool {
        if case .valid = status(vin) { return true }
        return false
    }

    public static func status(_ vin: String) -> Status {
        let characters = Array(normalize(vin))
        guard characters.count == 17 else { return .wrongLength(characters.count) }
        var values: [Int] = []
        values.reserveCapacity(17)
        for character in characters {
            guard let value = transliterated(character) else { return .illegalCharacter(character) }
            values.append(value)
        }
        let sum = zip(values, weights).reduce(0) { $0 + $1.0 * $1.1 }
        let remainder = sum % 11
        let expected: Character = remainder == 10 ? "X" : Character(String(remainder))
        guard characters[8] == expected else { return .badCheckDigit(expected: expected) }
        return .valid
    }

    private static func transliterated(_ character: Character) -> Int? {
        if let digit = asciiDigit(character) { return digit }
        switch character {
        case "A", "J": return 1
        case "B", "K", "S": return 2
        case "C", "L", "T": return 3
        case "D", "M", "U": return 4
        case "E", "N", "V": return 5
        case "F", "W": return 6
        case "G", "P", "X": return 7
        case "H", "Y": return 8
        case "R", "Z": return 9
        default: return nil
        }
    }

    private static func asciiDigit(_ character: Character) -> Int? {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1,
              (48...57).contains(scalar.value) else { return nil }
        return Int(scalar.value - 48)
    }
}
