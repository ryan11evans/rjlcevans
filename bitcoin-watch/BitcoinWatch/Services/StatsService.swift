import Foundation

@MainActor
class StatsService: ObservableObject {
    static let shared = StatsService()

    @Published var stats: BitcoinStats?
    @Published var chartData: [ChartPoint] = []
    @Published var chartRange: ChartRange = .day

    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let price: Double
    }

    enum ChartRange: String, CaseIterable {
        case day = "1D"
        case week = "7D"
        case month = "30D"
        var days: Int {
            switch self { case .day: return 1; case .week: return 7; case .month: return 30 }
        }
    }

    private let geckoURL = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false")!
    private let blockURL = URL(string: "https://blockstream.info/api/blocks/tip/height")!

    func fetch() async {
        async let market = fetchMarket()
        async let block  = fetchBlock()
        let (m, b) = await (market, block)
        guard let m, let b else { return }

        // Keep current price and 24h band consistent by clamping the band to include it
        let current = m.currentPrice
        let low  = min(m.low24h,  current)
        let high = max(m.high24h, current)

        // Also update the shared price so PriceService shows the same number
        let price = BitcoinPrice(usd: current, timestamp: Date())
        UserDefaults.shared.savePrice(price)

        stats = BitcoinStats(currentPrice: current,
                             high24h: high, low24h: low,
                             ath: m.ath, athDate: m.athDate,
                             change24h: m.change24h, blockHeight: b)

        if chartData.isEmpty {
            await fetchChart(range: chartRange)
        }
    }

    func fetchChart(range: ChartRange) async {
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=\(range.days)")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct R: Decodable { let prices: [[Double]] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        chartData = r.prices.map { pair in
            ChartPoint(date: Date(timeIntervalSince1970: pair[0] / 1000), price: pair[1])
        }
        chartRange = range
    }

    private struct MarketResult {
        let currentPrice, high24h, low24h, ath, change24h: Double
        let athDate: Date
    }

    private func fetchMarket() async -> MarketResult? {
        guard let (data, _) = try? await URLSession.shared.data(from: geckoURL) else { return nil }
        struct R: Decodable {
            struct MD: Decodable {
                struct V: Decodable { let usd: Double }
                struct D: Decodable { let usd: String }
                let current_price: V
                let high_24h: V; let low_24h: V; let ath: V; let ath_date: D
                let price_change_percentage_24h: Double
            }
            let market_data: MD
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = df.date(from: r.market_data.ath_date.usd) ?? Date()
        return MarketResult(currentPrice: r.market_data.current_price.usd,
                            high24h:      r.market_data.high_24h.usd,
                            low24h:       r.market_data.low_24h.usd,
                            ath:          r.market_data.ath.usd,
                            change24h:    r.market_data.price_change_percentage_24h,
                            athDate:      date)
    }

    private func fetchBlock() async -> Int? {
        guard let (data, _) = try? await URLSession.shared.data(from: blockURL),
              let text = String(data: data, encoding: .utf8),
              let h = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return h
    }
}

struct BitcoinStats {
    let currentPrice: Double
    let high24h:      Double
    let low24h:       Double
    let ath:          Double
    let athDate:      Date
    let change24h:    Double
    let blockHeight:  Int
}
