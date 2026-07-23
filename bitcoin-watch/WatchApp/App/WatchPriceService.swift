import Foundation
import Combine
import ClockKit

@MainActor
class WatchPriceService: ObservableObject {
    static let shared = WatchPriceService()

    @Published var currentPrice: BitcoinPrice?
    @Published var isLoading = false
    @Published var holdingsAmount: Double = UserDefaults.shared.double(forKey: "btcHoldings")
    @Published var isPro: Bool = UserDefaults.shared.bool(forKey: "isProUnlocked")

    private var refreshTask: Task<Void, Never>?
    private let foregroundInterval: TimeInterval = 10  // 10s while Watch app is open

    init() {
        currentPrice = UserDefaults.shared.loadPrice()
    }

    /// Live portfolio value — Pro only, and only when holdings are set.
    var holdingsValue: Double? {
        guard isPro, holdingsAmount > 0, let p = currentPrice?.usd else { return nil }
        return holdingsAmount * p
    }

    func update(price: BitcoinPrice) {
        currentPrice = price
        UserDefaults.shared.savePrice(price)
        reloadComplications()
    }

    func updateHoldings(amount: Double, isPro: Bool) {
        holdingsAmount = amount
        self.isPro = isPro
        UserDefaults.shared.set(amount, forKey: "btcHoldings")
        UserDefaults.shared.set(isPro, forKey: "isProUnlocked")
    }

    func startForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetchDirect()
                try? await Task.sleep(nanoseconds: UInt64(foregroundInterval * 1_000_000_000))
            }
        }
    }

    func stopForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    @discardableResult
    func fetchDirect() async -> BitcoinPrice? {
        isLoading = true
        defer { isLoading = false }
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-\(AppCurrency.current.code)/spot"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { struct D: Decodable { let amount: String }; let data: D }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let val = Double(r.data.amount) else { return nil }
        let price = BitcoinPrice(usd: val, timestamp: Date())
        update(price: price)
        return price
    }

    private func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}
