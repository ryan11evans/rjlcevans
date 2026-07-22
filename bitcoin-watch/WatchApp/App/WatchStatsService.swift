import Foundation

@MainActor
class WatchStatsService: ObservableObject {
    static let shared = WatchStatsService()

    @Published var high24h: Double?
    @Published var low24h: Double?
    @Published var ath: Double?
    @Published var change24h: Double?
    @Published var blockHeight: Int?
    @Published var chartPoints: [ChartPoint] = []

    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let price: Double
    }

    private var lastFetch: Date?

    func fetchIfNeeded() async {
        // Watch budget is tight — refresh stats at most every 5 minutes
        if let last = lastFetch, Date().timeIntervalSince(last) < 300 { return }
        lastFetch = Date()
        async let market: Void = fetchMarket()
        async let chart:  Void = fetchChart()
        async let block:  Void = fetchBlock()
        _ = await (market, chart, block)
    }

    private func fetchMarket() async {
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct R: Decodable {
            struct MD: Decodable {
                let high_24h: [String: Double]
                let low_24h: [String: Double]
                let ath: [String: Double]
                let price_change_percentage_24h: Double
            }
            let market_data: MD
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        let cur = AppCurrency.current.rawValue
        high24h   = r.market_data.high_24h[cur]
        low24h    = r.market_data.low_24h[cur]
        ath       = r.market_data.ath[cur]
        change24h = r.market_data.price_change_percentage_24h
    }

    private func fetchChart() async {
        let vs = AppCurrency.current.rawValue
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=\(vs)&days=1")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct R: Decodable { let prices: [[Double]] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        chartPoints = r.prices.map {
            ChartPoint(date: Date(timeIntervalSince1970: $0[0] / 1000), price: $0[1])
        }
    }

    private func fetchBlock() async {
        let url = URL(string: "https://blockstream.info/api/blocks/tip/height")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let text = String(data: data, encoding: .utf8),
              let h = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        blockHeight = h
    }
}
