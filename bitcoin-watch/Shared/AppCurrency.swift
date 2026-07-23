import Foundation

// The fiat currency the whole app displays prices in. Stored in the shared app
// group so the widget reads it directly; synced to the Watch over WatchConnectivity.
enum AppCurrency: String, CaseIterable, Codable {
    case usd, eur, gbp, cad, aud, jpy

    var code: String { rawValue.uppercased() }

    var symbol: String {
        switch self {
        case .usd, .cad, .aud: return "$"
        case .eur:             return "€"
        case .gbp:             return "£"
        case .jpy:             return "¥"
        }
    }

    var displayName: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .cad: return "Canadian Dollar"
        case .aud: return "Australian Dollar"
        case .jpy: return "Japanese Yen"
        }
    }

    // Where the symbol is ambiguous (CAD/AUD both use $), append the code.
    var pickerLabel: String {
        switch self {
        case .cad: return "CAD $"
        case .aud: return "AUD $"
        default:   return "\(symbol) \(code)"
        }
    }

    static var current: AppCurrency {
        AppCurrency(rawValue: UserDefaults.shared.string(forKey: "displayCurrency") ?? "usd") ?? .usd
    }

    // Full formatted price, e.g. "$62,345" or "€57,890".
    func format(_ value: Double, fractionDigits: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.currencySymbol = symbol
        f.maximumFractionDigits = fractionDigits
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(symbol)\(Int(value))"
    }

    // Compact form, e.g. "$62.3K" / "$1.05M".
    func formatShort(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%@%.2fM", symbol, value / 1_000_000) }
        if value >= 1_000     { return String(format: "%@%.1fK", symbol, value / 1_000) }
        return String(format: "%@%.0f", symbol, value)
    }
}

// Sats denomination toggle — when on, BTC amounts are shown in satoshis.
enum SatsDisplay {
    static let satsPerBTC: Double = 100_000_000

    static var enabled: Bool { UserDefaults.shared.bool(forKey: "denominateInSats") }

    /// Formats a BTC amount as either "0.042 BTC" or "4,200,000 sats".
    static func formatAmount(_ btc: Double) -> String {
        if enabled {
            let sats = btc * satsPerBTC
            return "\(Int(sats).formatted()) sats"
        }
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return "\(f.string(from: NSNumber(value: btc)) ?? "\(btc)") BTC"
    }
}
