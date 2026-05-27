import Foundation

struct BitcoinPrice: Codable, Equatable {
    let usd: Double
    let timestamp: Date

    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: usd)) ?? "$\(Int(usd))"
    }

    var shortFormatted: String {
        if usd >= 1_000_000 {
            return String(format: "$%.2fM", usd / 1_000_000)
        } else if usd >= 1_000 {
            return String(format: "$%.1fK", usd / 1_000)
        }
        return String(format: "$%.0f", usd)
    }
}

// Shared UserDefaults suite for App Group data sharing between app, widget, watch
extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.rjlcevans.bitcoinwatch") ?? .standard

    func savePrice(_ price: BitcoinPrice) {
        if let data = try? JSONEncoder().encode(price) {
            set(data, forKey: "lastBitcoinPrice")
        }
    }

    func loadPrice() -> BitcoinPrice? {
        guard let data = data(forKey: "lastBitcoinPrice") else { return nil }
        return try? JSONDecoder().decode(BitcoinPrice.self, from: data)
    }
}

// WatchConnectivity message keys
enum WCMessageKey {
    static let price = "btcPrice"
    static let timestamp = "btcTimestamp"
}
