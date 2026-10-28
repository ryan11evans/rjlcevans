import Foundation

/// JSON object of tax-year string → decimal string.
/// SwiftData on iOS 17 does not persist `[Int: Decimal]`, so Employer.codeTT and
/// VehicleLoan.actualInterest store this blob and expose the dictionary as a computed property.
enum YearAmountStorage {
    static func encode(_ amounts: [Int: Decimal]) -> Data {
        let payload = Dictionary(uniqueKeysWithValues: amounts.map { (String($0.key), decimalString($0.value)) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    static func decode(_ data: Data) -> [Int: Decimal] {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        var amounts: [Int: Decimal] = [:]
        for (year, literal) in payload {
            guard let year = Int(year),
                  let amount = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else { continue }
            amounts[year] = amount
        }
        return amounts
    }

    private static func decimalString(_ value: Decimal) -> String {
        // `stringValue` is not localized, so a stored "10.5" round-trips through POSIX parsing.
        NSDecimalNumber(decimal: value).stringValue
    }
}
