import Foundation

// Live BTC price in every supported currency, captured together from one
// CoinGecko fetch (StatsService.fetchMarket) so cross-currency conversion
// stays internally consistent. Lets us compare/convert values that were
// recorded in a currency other than the one the user has selected right now
// (a historical USD halving price, a purchase lot entered before a currency
// switch, a price alert created under a different display currency).
@MainActor
final class CurrencyRates {
    static let shared = CurrencyRates()

    private var btcPrice: [AppCurrency: Double] = [:]

    func update(_ prices: [AppCurrency: Double]) {
        btcPrice = prices
    }

    /// Converts a BTC-denominated amount from one currency to another using
    /// each currency's live BTC price as the cross rate. Falls back to
    /// returning `amount` unchanged if a live rate isn't available yet —
    /// that's the same assumption the app made everywhere before rates
    /// existed, so it never behaves worse than today while rates warm up.
    func convert(_ amount: Double, from: AppCurrency, to: AppCurrency) -> Double {
        guard from != to,
              let fromRate = btcPrice[from], fromRate > 0,
              let toRate = btcPrice[to] else { return amount }
        return amount * (toRate / fromRate)
    }
}
