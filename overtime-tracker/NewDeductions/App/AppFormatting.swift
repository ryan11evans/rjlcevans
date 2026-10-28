import Foundation
import OvertimeCore

enum AppFormatting {
    static let marginalBrackets = [10, 12, 22, 24, 32, 35, 37]

    static func filingStatusTitle(_ status: FilingStatus) -> String {
        switch status {
        case .single: "Single"
        case .headOfHousehold: "Head of household"
        case .marriedFilingJointly: "Married filing jointly"
        case .marriedFilingSeparately: "Married filing separately"
        case .qualifyingSurvivingSpouse: "Qualifying surviving spouse"
        }
    }

    /// `Calendar` weekday numbers: 1 = Sunday … 7 = Saturday, independent of the locale's first weekday.
    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "Day \(weekday)"
        }
    }

    static func currency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func percent(_ rate: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        let points = formatter.string(from: (rate * 100) as NSDecimalNumber) ?? "\(rate * 100)"
        return "\(points)%"
    }

    static func hours(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    static func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// A decimal the user can put back into a text field. Not localized.
    static func editableDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func plainDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func nearestBracketPercent(_ rate: Decimal) -> Int {
        let points = NSDecimalNumber(decimal: rate * 100).intValue
        return marginalBrackets.min { abs($0 - points) < abs($1 - points) } ?? 22
    }

    static func parseDecimal(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
