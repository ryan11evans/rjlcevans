import Foundation
import Combine
import ClockKit

@MainActor
class WatchPriceService: ObservableObject {
    static let shared = WatchPriceService()

    @Published var currentPrice: BitcoinPrice?
    @Published var isLoading = false

    private var refreshTask: Task<Void, Never>?
    private let foregroundInterval: TimeInterval = 10  // 10s while Watch app is open

    init() {
        currentPrice = UserDefaults.shared.loadPrice()
    }

    func update(price: BitcoinPrice) {
        currentPrice = price
        UserDefaults.shared.savePrice(price)
        reloadComplications()
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
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot"),
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
