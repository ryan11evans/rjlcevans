import Foundation

@MainActor
class StatsService: ObservableObject {
    static let shared = StatsService()

    @Published var stats: BitcoinStats?
    @Published var chartData: [ChartPoint] = []
    @Published var chartRange: ChartRange = .day
    @Published var fearGreed: FearGreedData? = nil

    struct FearGreedData {
        let value: Int
        let classification: String

        var color: String {
            switch value {
            case 0..<25:  return "red"
            case 25..<50: return "orange"
            case 50..<75: return "green"
            default:      return "yellow"
            }
        }
    }

    struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let price: Double
    }

    enum ChartRange: String, CaseIterable {
        case day = "1D"
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
        case year = "1Y"
        case all = "All"
        // CoinGecko market_chart `days` param — "max" for all-time.
        var daysParam: String {
            switch self {
            case .day: return "1"; case .week: return "7"; case .month: return "30"
            case .quarter: return "90"; case .year: return "365"; case .all: return "max"
            }
        }
    }

    private let geckoURL = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false")!
    private let blockURL = URL(string: "https://blockstream.info/api/blocks/tip/height")!
    private var autoRefreshTask: Task<Void, Never>?

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await fetch()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // Called every 15s by PriceService to keep the chart's right edge current.
    // Uses a 10-minute window so we always UPDATE the last CoinGecko point
    // rather than appending a new one (which would cause a visible price spike).
    func updateLivePrice(_ usd: Double) {
        guard !chartData.isEmpty else { return }
        let now = Date()
        if let last = chartData.last, now.timeIntervalSince(last.date) < 600 {
            chartData[chartData.count - 1] = ChartPoint(date: now, price: usd)
        } else {
            chartData.append(ChartPoint(date: now, price: usd))
        }
    }

    func fetch() async {
        async let market   = fetchMarket()
        async let block    = fetchBlock()
        async let fng      = fetchFearGreed()
        let (m, b, fg) = await (market, block, fng)
        if let fg { fearGreed = fg }
        guard let m, let b else { return }

        // Keep current price and 24h band consistent by clamping the band to include it
        let current = m.currentPrice
        let low  = min(m.low24h,  current)
        let high = max(m.high24h, current)

        // Also update the shared price so PriceService shows the same number
        let price = BitcoinPrice(usd: current, timestamp: Date())
        UserDefaults.shared.savePrice(price)
        UserDefaults.shared.saveChange24h(m.change24h)

        stats = BitcoinStats(currentPrice: current,
                             high24h: high, low24h: low,
                             ath: m.ath, athDate: m.athDate,
                             change24h: m.change24h, blockHeight: b)

        await fetchChart(range: chartRange)
    }

    func fetchChart(range: ChartRange) async {
        let vs = AppCurrency.current.rawValue
        let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=\(vs)&days=\(range.daysParam)")!
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        struct R: Decodable { let prices: [[Double]] }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        let points = r.prices.map { pair in
            ChartPoint(date: Date(timeIntervalSince1970: pair[0] / 1000), price: pair[1])
        }
        chartData = points
        chartRange = range
    }

    private struct MarketResult {
        let currentPrice, high24h, low24h, ath, change24h: Double
        let athDate: Date
    }

    private func fetchMarket() async -> MarketResult? {
        guard let (data, _) = try? await URLSession.shared.data(from: geckoURL) else { return nil }
        // CoinGecko returns each price field keyed by currency code, so decode
        // dictionaries and pick the user's selected currency.
        struct R: Decodable {
            struct MD: Decodable {
                let current_price: [String: Double]
                let high_24h: [String: Double]
                let low_24h: [String: Double]
                let ath: [String: Double]
                let ath_date: [String: String]
                let price_change_percentage_24h: Double
            }
            let market_data: MD
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        let cur = AppCurrency.current.rawValue
        let md = r.market_data
        guard let current = md.current_price[cur] else { return nil }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = df.date(from: md.ath_date[cur] ?? "") ?? Date()
        return MarketResult(currentPrice: current,
                            high24h:      md.high_24h[cur] ?? current,
                            low24h:       md.low_24h[cur] ?? current,
                            ath:          md.ath[cur] ?? current,
                            change24h:    md.price_change_percentage_24h,
                            athDate:      date)
    }

    private func fetchFearGreed() async -> FearGreedData? {
        guard let url = URL(string: "https://api.alternative.me/fng/"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable {
            struct Entry: Decodable {
                let value: String
                let value_classification: String
            }
            let data: [Entry]
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let entry = r.data.first,
              let value = Int(entry.value) else { return nil }
        return FearGreedData(value: value, classification: entry.value_classification)
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
