import Foundation
import WidgetKit

// One Bitcoin purchase (lot). `price` is the per-BTC cost in the app's display
// currency at entry time; 0 means "cost unknown" (value tracked, no P&L).
struct Purchase: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Double
    var price: Double
    var date: Date = Date()
}

// Stores the user's Bitcoin holdings as a list of purchases, locally in the
// shared app group so the widget and Watch can read the aggregates. No account.
@MainActor
final class HoldingsService: ObservableObject {
    static let shared = HoldingsService()

    @Published private(set) var purchases: [Purchase]

    private let key = "btcPurchases"
    private let legacyAmountKey = "btcHoldings"

    init() {
        if let data = UserDefaults.shared.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Purchase].self, from: data) {
            purchases = decoded
        } else {
            // Migrate a legacy plain amount into a single cost-less lot.
            let legacy = UserDefaults.shared.double(forKey: legacyAmountKey)
            purchases = legacy > 0 ? [Purchase(amount: legacy, price: 0)] : []
        }
    }

    // MARK: Aggregates

    var totalAmount: Double { purchases.reduce(0) { $0 + $1.amount } }
    var hasHoldings: Bool { totalAmount > 0 }

    private var costLots: [Purchase] { purchases.filter { $0.price > 0 && $0.amount > 0 } }
    var investedBTC: Double { costLots.reduce(0) { $0 + $1.amount } }
    var totalInvested: Double { costLots.reduce(0) { $0 + $1.amount * $1.price } }
    var hasCostBasis: Bool { investedBTC > 0 }
    var avgCost: Double? { hasCostBasis ? totalInvested / investedBTC : nil }

    func value(at price: Double) -> Double { totalAmount * price }

    /// Profit/loss on the portion of the stack that has a known cost.
    func gain(at price: Double) -> (amount: Double, pct: Double)? {
        guard hasCostBasis else { return nil }
        let now = investedBTC * price
        return (now - totalInvested, now / totalInvested - 1)
    }

    var formattedAmount: String { SatsDisplay.formatAmount(totalAmount) }

    // MARK: Mutations

    func add(_ purchase: Purchase) {
        purchases.append(purchase)
        persist()
    }

    func remove(_ purchase: Purchase) {
        purchases.removeAll { $0.id == purchase.id }
        persist()
    }

    func remove(at offsets: IndexSet) {
        purchases.remove(atOffsets: offsets)
        persist()
    }

    /// Quick mode: replace everything with a single lot (price 0 = no cost).
    func setSingle(amount: Double, price: Double) {
        purchases = amount > 0 ? [Purchase(amount: amount, price: price)] : []
        persist()
    }

    func clear() {
        purchases = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(purchases) {
            UserDefaults.shared.set(data, forKey: key)
        }
        // Mirror aggregates under simple keys the widget / Watch / server read.
        UserDefaults.shared.set(totalAmount, forKey: legacyAmountKey)
        UserDefaults.shared.set(avgCost ?? 0, forKey: "btcAvgCost")
        UserDefaults.shared.set(investedBTC, forKey: "btcInvestedBTC")
        UserDefaults.shared.set(totalInvested, forKey: "btcTotalInvested")

        WidgetCenter.shared.reloadAllTimelines()
        ConnectivityManager.shared.syncHoldings()
        Task { await PushService.shared.sync() }
    }
}
