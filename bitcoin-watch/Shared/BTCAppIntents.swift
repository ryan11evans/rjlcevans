import AppIntents
import WidgetKit
import Foundation

// MARK: - Get Price

struct GetBitcoinPriceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Bitcoin Price"
    static var description = IntentDescription("Get the current Bitcoin price in USD.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<Double> & ProvidesDialog {
        let price = UserDefaults.shared.loadPrice()?.usd ?? 0
        let formatted = priceString(price)
        return .result(value: price,
                       dialog: IntentDialog(stringLiteral: "Bitcoin is currently \(formatted)."))
    }

    private func priceString(_ usd: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: usd)) ?? "$\(Int(usd))"
    }
}

// MARK: - Convert to Sats

struct ConvertToSatoshisIntent: AppIntent {
    static var title: LocalizedStringResource = "Convert Dollars to Satoshis"
    static var description = IntentDescription("Convert a USD amount to satoshis using the live Bitcoin price.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "US Dollars",
               description: "The dollar amount to convert.",
               requestValueDialog: "How many dollars would you like to convert?")
    var dollars: Double

    func perform() async throws -> some ReturnsValue<Int> & ProvidesDialog {
        guard let btcPrice = UserDefaults.shared.loadPrice()?.usd, btcPrice > 0 else {
            return .result(value: 0,
                           dialog: "Bitcoin price isn't available yet. Open TapBTC first to load the price.")
        }
        let sats = Int((dollars / btcPrice) * 100_000_000)
        let f = NumberFormatter(); f.numberStyle = .decimal
        let satsStr = f.string(from: NSNumber(value: sats)) ?? "\(sats)"
        let usdStr = String(format: "$%.2f", dollars)
        return .result(value: sats,
                       dialog: IntentDialog(stringLiteral: "\(usdStr) equals \(satsStr) satoshis at the current Bitcoin price."))
    }
}

// MARK: - Shortcuts provider — registers Siri phrases automatically

struct BTCShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetBitcoinPriceIntent(),
            phrases: [
                "What's Bitcoin at in \(.applicationName)",
                "Bitcoin price in \(.applicationName)",
                "What's BTC worth in \(.applicationName)",
                "Check Bitcoin in \(.applicationName)",
                "BTC price in \(.applicationName)"
            ],
            shortTitle: "Bitcoin Price",
            systemImageName: "bitcoinsign.circle.fill"
        )
        AppShortcut(
            intent: ConvertToSatoshisIntent(),
            phrases: [
                "Convert dollars to sats in \(.applicationName)",
                "How many sats is \(\.$dollars) in \(.applicationName)",
                "Satoshi calculator in \(.applicationName)"
            ],
            shortTitle: "Convert to Sats",
            systemImageName: "plusminus"
        )
    }
}
