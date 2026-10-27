import Foundation

struct BitcoinPrice: Codable, Equatable {
    // Historically USD; now holds the price in the user's selected display
    // currency (see AppCurrency). Kept named `usd` to avoid a churny rename.
    let usd: Double
    let timestamp: Date

    var formatted: String {
        AppCurrency.current.format(usd, fractionDigits: 0)
    }

    var circularFormatted: String {
        if usd >= 1_000_000 {
            return String(format: "%.2fM", usd / 1_000_000)
        } else if usd >= 1_000 {
            return String(format: "%.1fK", usd / 1_000)
        }
        return String(format: "%.0f", usd)
    }

    var shortFormatted: String {
        AppCurrency.current.formatShort(usd)
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

    func saveChange24h(_ change: Double) { set(change, forKey: "btcChange24h") }
    func loadChange24h() -> Double? { object(forKey: "btcChange24h") as? Double }

    // Sparkline points for the widgets (downsampled 1D prices).
    func saveSparkline(_ prices: [Double]) { set(prices, forKey: "btcSparkline") }
    func loadSparkline() -> [Double] { array(forKey: "btcSparkline") as? [Double] ?? [] }

    // Extra stats surfaced in the large widget.
    func saveWidgetStats(high: Double, low: Double, ath: Double, fng: Int?) {
        set(high, forKey: "wHigh24h"); set(low, forKey: "wLow24h"); set(ath, forKey: "wATH")
        if let fng { set(fng, forKey: "wFNG") } else { removeObject(forKey: "wFNG") }
    }
    func loadWidgetStats() -> (high: Double, low: Double, ath: Double, fng: Int?)? {
        guard let high = object(forKey: "wHigh24h") as? Double,
              let low = object(forKey: "wLow24h") as? Double,
              let ath = object(forKey: "wATH") as? Double else { return nil }
        return (high, low, ath, object(forKey: "wFNG") as? Int)
    }
}

// WatchConnectivity message keys
enum WCMessageKey {
    static let price = "btcPrice"
    static let timestamp = "btcTimestamp"
    static let holdings = "btcHoldings"
    static let isPro = "isPro"
    static let currency = "displayCurrency"
}

// Why a paywall was opened. Shared with the widget so a Home Screen tap can
// deep-link straight to the matching benefit.
enum PaywallTrigger: String, Identifiable {
    case settings
    case widget
    case holdings
    case alerts
    case volatility
    case briefing
    case icon
    case theme
    /// First-launch walkthrough. Not sent by the widget.
    case onboarding

    var id: String { rawValue }
}

enum TapBTCLink {
    static let scheme = "tapbtc"

    static func paywall(_ trigger: PaywallTrigger) -> URL {
        URL(string: "\(scheme)://pro?trigger=\(trigger.rawValue)")!
    }

    /// `tapbtc://pro?trigger=widget` (and the same host with any known trigger).
    static func paywallTrigger(from url: URL) -> PaywallTrigger? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        guard host == "pro" || path == "/pro" || path.hasSuffix("/pro") else { return nil }
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "trigger" }?
            .value?
            .lowercased()
        if let raw, let trigger = PaywallTrigger(rawValue: raw) { return trigger }
        return .widget
    }
}
