import WidgetKit
import SwiftUI
import Charts

// ── Shared colors / helpers ──────────────────────────────────────────────────

private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)
private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

private func trendColor(_ change: Double?) -> Color {
    (change ?? 0) >= 0 ? upColor : downColor
}

// Dark branded background with an orange glow, matching the app.
private struct WidgetBackground: View {
    var tint: Color = .orange
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.10, blue: 0.09),
                         Color(red: 0.04, green: 0.035, blue: 0.03)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [tint.opacity(0.16), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 240
            )
        }
    }
}

// ── Timeline ─────────────────────────────────────────────────────────────────

struct BitcoinProvider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date(), price: BitcoinPrice(usd: 65000, timestamp: Date()), change24h: 2.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        completion(makeEntry(price: UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 65000, timestamp: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let price = await fetchLatestPrice() ?? UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 0, timestamp: Date())
            // Keep the trend line fresh even when the app hasn't been opened.
            if let spark = await fetchSparkline() { UserDefaults.shared.saveSparkline(spark) }
            let entry = makeEntry(price: price)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchSparkline() async -> [Double]? {
        let vs = AppCurrency.current.rawValue
        guard let url = URL(string: "https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=\(vs)&days=1"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { let prices: [[Double]] }
        guard let r = try? JSONDecoder().decode(R.self, from: data), !r.prices.isEmpty else { return nil }
        let prices = r.prices.map { $0[1] }
        let step = max(1, prices.count / 48)
        return stride(from: 0, to: prices.count, by: step).map { prices[$0] }
    }

    private func makeEntry(price: BitcoinPrice) -> PriceEntry {
        let stats = UserDefaults.shared.loadWidgetStats()
        return PriceEntry(
            date: Date(),
            price: price,
            change24h: UserDefaults.shared.loadChange24h(),
            sparkline: UserDefaults.shared.loadSparkline(),
            high24h: stats?.high, low24h: stats?.low, ath: stats?.ath, fng: stats?.fng,
            holdingsValue: holdingsValue(at: price.usd),
            holdingsGainPct: holdingsGainPct(at: price.usd)
        )
    }

    private func fetchLatestPrice() async -> BitcoinPrice? {
        let code = AppCurrency.current.code
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-\(code)/spot") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { struct D: Decodable { let amount: String }; let data: D }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let val = Double(r.data.amount) else { return nil }
        let price = BitcoinPrice(usd: val, timestamp: Date())
        UserDefaults.shared.savePrice(price)
        return price
    }

    private func holdingsValue(at price: Double) -> Double? {
        guard UserDefaults.shared.bool(forKey: "isProUnlocked") else { return nil }
        let amount = UserDefaults.shared.double(forKey: "btcHoldings")
        guard amount > 0, price > 0 else { return nil }
        return amount * price
    }

    private func holdingsGainPct(at price: Double) -> Double? {
        guard UserDefaults.shared.bool(forKey: "isProUnlocked") else { return nil }
        let investedBTC = UserDefaults.shared.double(forKey: "btcInvestedBTC")
        let totalInvested = UserDefaults.shared.double(forKey: "btcTotalInvested")
        guard investedBTC > 0, totalInvested > 0, price > 0 else { return nil }
        return (investedBTC * price) / totalInvested - 1
    }
}

struct PriceEntry: TimelineEntry {
    let date: Date
    let price: BitcoinPrice
    let change24h: Double?
    var sparkline: [Double] = []
    var high24h: Double? = nil
    var low24h: Double? = nil
    var ath: Double? = nil
    var fng: Int? = nil
    var holdingsValue: Double? = nil
    var holdingsGainPct: Double? = nil
}

// ── Sparkline ────────────────────────────────────────────────────────────────

private struct Sparkline: View {
    let prices: [Double]
    let color: Color
    var body: some View {
        if prices.count > 1, let lo = prices.min(), let hi = prices.max(), hi > lo {
            Chart(Array(prices.indices), id: \.self) { i in
                LineMark(x: .value("i", i), y: .value("p", prices[i]))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("i", i), y: .value("p", prices[i]))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), .clear],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: (lo * 0.999)...(hi * 1.001))
        } else {
            Color.clear
        }
    }
}

// ── Price widget views ───────────────────────────────────────────────────────

struct BitcoinWidgetView: View {
    let entry: PriceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:   SmallWidgetView(entry: entry)
        case .systemMedium:  MediumWidgetView(entry: entry)
        case .systemLarge:   LargeWidgetView(entry: entry)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetView(entry: entry, family: family)
        default:             SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange)
                Spacer()
                if let change = entry.change24h {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(trendColor(change))
                }
            }
            Text(entry.price.formatted)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5).lineLimit(1)
            Sparkline(prices: entry.sparkline, color: trendColor(entry.change24h))
                .frame(maxWidth: .infinity)
            Text(entry.price.timestamp, style: .relative)
                .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
        .containerBackground(for: .widget) { WidgetBackground(tint: trendColor(entry.change24h)) }
    }
}

struct MediumWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange).font(.subheadline)
                    Text("Bitcoin").font(.subheadline.weight(.semibold))
                }
                Text(entry.price.formatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
                if let change = entry.change24h {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(trendColor(change))
                }
                if let stack = entry.holdingsValue {
                    Text("Stack · \(AppCurrency.current.format(stack))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Sparkline(prices: entry.sparkline, color: trendColor(entry.change24h))
                .frame(width: 150)
        }
        .containerBackground(for: .widget) { WidgetBackground(tint: trendColor(entry.change24h)) }
    }
}

struct LargeWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange)
                Text("Bitcoin").font(.headline)
                Spacer()
                Text(entry.price.timestamp, style: .relative)
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(entry.price.formatted)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
                if let change = entry.change24h {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(trendColor(change))
                }
            }

            Sparkline(prices: entry.sparkline, color: trendColor(entry.change24h))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 70)

            // Stats row
            HStack(spacing: 8) {
                if let h = entry.high24h { statTile("24H HIGH", AppCurrency.current.formatShort(h), upColor) }
                if let l = entry.low24h  { statTile("24H LOW",  AppCurrency.current.formatShort(l), downColor) }
                if let a = entry.ath     { statTile("ATH",      AppCurrency.current.formatShort(a), .orange) }
                if let f = entry.fng     { statTile("FEAR/GREED", "\(f)", .cyan) }
            }

            if let stack = entry.holdingsValue {
                HStack {
                    Text("YOUR STACK")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary).tracking(0.5)
                    Spacer()
                    Text(AppCurrency.current.format(stack))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    if let pct = entry.holdingsGainPct {
                        Text("\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(trendColor(pct))
                    }
                }
                .padding(.top, 2)
            }
        }
        .containerBackground(for: .widget) { WidgetBackground(tint: trendColor(entry.change24h)) }
    }

    private func statTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary).minimumScaleFactor(0.7).lineLimit(1)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
    }
}

// ── My Stack (portfolio) widget ──────────────────────────────────────────────

struct PortfolioWidgetView: View {
    let entry: PriceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let stack = entry.holdingsValue {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 3 : 5) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange).font(.caption)
                    Text("YOUR STACK")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary).tracking(0.5)
                }
                Text(AppCurrency.current.format(stack))
                    .font(.system(size: family == .systemSmall ? 26 : 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                if let pct = entry.holdingsGainPct {
                    Text("\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct * 100))% all-time")
                        .font(.system(size: family == .systemSmall ? 12 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(trendColor(pct))
                }
                if family != .systemSmall {
                    Sparkline(prices: entry.sparkline, color: trendColor(entry.change24h))
                        .frame(maxWidth: .infinity).frame(minHeight: 44)
                }
                if family == .systemMedium || family == .systemSmall {
                    Text("BTC \(entry.price.shortFormatted)")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { WidgetBackground(tint: trendColor(entry.holdingsGainPct ?? entry.change24h)) }
        } else {
            // No holdings / not Pro — invite them in.
            VStack(spacing: 6) {
                Image(systemName: "bitcoinsign.circle.fill").font(.title).foregroundStyle(.orange)
                Text("Track your Bitcoin")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Add your holdings in TapBTC")
                    .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { WidgetBackground() }
        }
    }
}

// ── Lock Screen / StandBy ────────────────────────────────────────────────────

struct AccessoryWidgetView: View {
    let entry: PriceEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "bitcoinsign.circle.fill").font(.caption2)
                Text(entry.price.shortFormatted)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
            .widgetAccentable()
        case .accessoryInline:
            Text("BTC \(entry.price.shortFormatted)").widgetAccentable()
        default: // .accessoryRectangular
            HStack {
                Image(systemName: "bitcoinsign.circle.fill").widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.price.formatted)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7).lineLimit(1)
                    if let stack = entry.holdingsValue {
                        Text("Stack \(AppCurrency.current.format(stack))")
                            .font(.caption2).foregroundStyle(.secondary)
                            .minimumScaleFactor(0.7).lineLimit(1)
                    } else if let change = entry.change24h {
                        Text(String(format: "%+.1f%% today", change))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

struct BTCPriceWidget: Widget {
    let kind = "BitcoinWatchWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BitcoinProvider()) { entry in
            BitcoinWidgetView(entry: entry)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live BTC price with a trend chart.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

struct BTCPortfolioWidget: Widget {
    let kind = "BitcoinPortfolioWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BitcoinProvider()) { entry in
            PortfolioWidgetView(entry: entry)
        }
        .configurationDisplayName("My Stack")
        .description("Your Bitcoin's live value and profit (Pro).")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BitcoinWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        BTCPriceWidget()
        BTCPortfolioWidget()
        BTCLiveActivityWidget()
    }
}
