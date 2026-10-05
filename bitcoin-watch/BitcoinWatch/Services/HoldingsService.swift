import Foundation
import WidgetKit

// One Bitcoin purchase (lot). `price` is the per-BTC cost in `currency` at
// entry time; 0 means "cost unknown" (value tracked, no P&L). `currency` is
// recorded so FIFO math stays correct even if the user changes their display
// currency in Settings later — without it, old and new lots would silently
// blend two currencies with no conversion or warning.
struct Purchase: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Double
    var price: Double
    var date: Date = Date()
    var currency: AppCurrency = .current

    private enum CodingKeys: String, CodingKey { case id, amount, price, date, currency }

    init(id: UUID = UUID(), amount: Double, price: Double, date: Date = Date(), currency: AppCurrency = .current) {
        self.id = id
        self.amount = amount
        self.price = price
        self.date = date
        self.currency = currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amount = try c.decode(Double.self, forKey: .amount)
        price = try c.decode(Double.self, forKey: .price)
        date = try c.decode(Date.self, forKey: .date)
        // Pre-fix lots predate per-lot currency tagging; best-effort default
        // to whatever currency is selected now rather than fabricating history.
        currency = try c.decodeIfPresent(AppCurrency.self, forKey: .currency) ?? .current
    }
}

// One Bitcoin sale. `price` is the per-BTC proceeds in `currency` at the time
// of sale. See `Purchase` for why `currency` is recorded per-entry.
struct Sale: Codable, Identifiable, Equatable {
    var id = UUID()
    var amount: Double
    var price: Double
    var date: Date = Date()
    var currency: AppCurrency = .current

    private enum CodingKeys: String, CodingKey { case id, amount, price, date, currency }

    init(id: UUID = UUID(), amount: Double, price: Double, date: Date = Date(), currency: AppCurrency = .current) {
        self.id = id
        self.amount = amount
        self.price = price
        self.date = date
        self.currency = currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amount = try c.decode(Double.self, forKey: .amount)
        price = try c.decode(Double.self, forKey: .price)
        date = try c.decode(Date.self, forKey: .date)
        currency = try c.decodeIfPresent(AppCurrency.self, forKey: .currency) ?? .current
    }
}

// Stores the user's Bitcoin holdings as a list of purchases and sales, locally
// in the shared app group so the widget and Watch can read the aggregates.
// No account. Realized/unrealized P&L is derived by matching sales against
// purchase lots FIFO (oldest lot sold first) — see `fifoResult`.
@MainActor
final class HoldingsService: ObservableObject {
    static let shared = HoldingsService()

    @Published private(set) var purchases: [Purchase]
    @Published private(set) var sales: [Sale]

    private let key = "btcPurchases"
    private let salesKey = "btcSales"
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
        if let data = UserDefaults.shared.data(forKey: salesKey),
           let decoded = try? JSONDecoder().decode([Sale].self, from: data) {
            sales = decoded
        } else {
            sales = []
        }
    }

    // MARK: FIFO lot matching

    private struct OpenLot { var amount: Double; var price: Double }

    /// Replays purchases (oldest first) against sales (oldest first), consuming
    /// each sale from the oldest still-open lots. Lots left over after all sales
    /// are the ones that still back current holdings / unrealized P&L; the
    /// consumed portions back realized P&L.
    private var fifoResult: (openLots: [OpenLot], realizedGain: Double, realizedCostBasis: Double) {
        // Convert every lot/sale price into the *current* display currency up
        // front, so the FIFO math below never blends currencies even if the
        // user switched since some entries were recorded (see `Purchase`/`Sale`).
        var lots = purchases
            .filter { $0.amount > 0 }
            .sorted { $0.date < $1.date }
            .map { OpenLot(amount: $0.amount,
                           price: CurrencyRates.shared.convert($0.price, from: $0.currency, to: .current)) }

        var realizedGain = 0.0
        var realizedCostBasis = 0.0

        for sale in sales.sorted(by: { $0.date < $1.date }) where sale.amount > 0 {
            let salePrice = CurrencyRates.shared.convert(sale.price, from: sale.currency, to: .current)
            var remaining = sale.amount
            var i = 0
            while remaining > 0, i < lots.count {
                guard lots[i].amount > 0 else { i += 1; continue }
                let consumed = min(remaining, lots[i].amount)
                if lots[i].price > 0 {
                    realizedGain += consumed * (salePrice - lots[i].price)
                    realizedCostBasis += consumed * lots[i].price
                }
                lots[i].amount -= consumed
                remaining -= consumed
                i += 1
            }
            // If a sale exceeds everything sold so far (bad manual entry), the
            // excess is simply dropped rather than going negative.
        }

        return (lots.filter { $0.amount > 1e-12 }, realizedGain, realizedCostBasis)
    }

    // MARK: Aggregates

    /// Currently held BTC — total purchased minus total sold (FIFO).
    var totalAmount: Double { fifoResult.openLots.reduce(0) { $0 + $1.amount } }
    var hasHoldings: Bool { totalAmount > 0 }

    private var openCostLots: [OpenLot] { fifoResult.openLots.filter { $0.price > 0 } }
    var investedBTC: Double { openCostLots.reduce(0) { $0 + $1.amount } }
    var totalInvested: Double { openCostLots.reduce(0) { $0 + $1.amount * $1.price } }
    var hasCostBasis: Bool { investedBTC > 0 }
    var avgCost: Double? { hasCostBasis ? totalInvested / investedBTC : nil }

    func value(at price: Double) -> Double { totalAmount * price }

    /// Unrealized profit/loss on the portion of the (still-held) stack that has a known cost.
    func gain(at price: Double) -> (amount: Double, pct: Double)? {
        guard hasCostBasis else { return nil }
        let now = investedBTC * price
        return (now - totalInvested, now / totalInvested - 1)
    }

    var hasSales: Bool { !sales.isEmpty }

    /// Realized profit/loss booked so far, from selling cost-basis lots.
    var realizedGain: Double { fifoResult.realizedGain }

    var realizedPct: Double? {
        let basis = fifoResult.realizedCostBasis
        return basis > 0 ? fifoResult.realizedGain / basis : nil
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

    func addSale(_ sale: Sale) {
        sales.append(sale)
        persist()
    }

    func removeSale(_ sale: Sale) {
        sales.removeAll { $0.id == sale.id }
        persist()
    }

    func removeSale(at offsets: IndexSet) {
        sales.remove(atOffsets: offsets)
        persist()
    }

    /// Quick mode: replace everything with a single lot (price 0 = no cost).
    func setSingle(amount: Double, price: Double) {
        purchases = amount > 0 ? [Purchase(amount: amount, price: price)] : []
        sales = []
        persist()
    }

    func clear() {
        purchases = []
        sales = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(purchases) {
            UserDefaults.shared.set(data, forKey: key)
        }
        if let data = try? JSONEncoder().encode(sales) {
            UserDefaults.shared.set(data, forKey: salesKey)
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
