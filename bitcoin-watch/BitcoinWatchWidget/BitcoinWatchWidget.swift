import WidgetKit
import SwiftUI

// Timeline provider — iOS calls getTimeline() to schedule widget refreshes.
// We request the next update in 10 minutes; iOS may round up, but this gives
// the fastest widget refresh rate allowed without a server push (push = fastest,
// but requires a notification infrastructure).
struct BitcoinProvider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date(), price: BitcoinPrice(usd: 65000, timestamp: Date()), change24h: 2.5)
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        let price = UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 65000, timestamp: Date())
        completion(PriceEntry(date: Date(), price: price, change24h: UserDefaults.shared.loadChange24h(),
                              holdingsValue: holdingsValue(at: price.usd)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let price = await fetchLatestPrice() ?? UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 0, timestamp: Date())
            let entry = PriceEntry(date: Date(), price: price, change24h: UserDefaults.shared.loadChange24h(),
                                   holdingsValue: holdingsValue(at: price.usd))
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // Portfolio value, only for Pro users who've entered holdings.
    private func holdingsValue(at price: Double) -> Double? {
        guard UserDefaults.shared.bool(forKey: "isProUnlocked") else { return nil }
        let amount = UserDefaults.shared.double(forKey: "btcHoldings")
        guard amount > 0, price > 0 else { return nil }
        return amount * price
    }

    private func fetchLatestPrice() async -> BitcoinPrice? {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { struct D: Decodable { let amount: String }; let data: D }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let val = Double(r.data.amount) else { return nil }
        let price = BitcoinPrice(usd: val, timestamp: Date())
        UserDefaults.shared.savePrice(price)
        return price
    }
}

struct PriceEntry: TimelineEntry {
    let date: Date
    let price: BitcoinPrice
    let change24h: Double?
    var holdingsValue: Double? = nil
}

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

// Center-aligned for StandBy — scales up beautifully on a nightstand display
struct SmallWidgetView: View {
    let entry: PriceEntry
    private var changeColor: Color {
        guard let c = entry.change24h else { return .secondary }
        return c >= 0 ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 1, green: 0.27, blue: 0.23)
    }
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 5) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 32))
                Text(entry.price.shortFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let change = entry.change24h {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(changeColor)
                }
                Text(entry.price.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(intent: RefreshBTCIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(.background, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("Bitcoin")
                        .font(.headline)
                }
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(entry.price.formatted)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let change = entry.change24h {
                        Text(String(format: "%+.1f%%", change))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(change >= 0
                                ? Color(red: 0.19, green: 0.82, blue: 0.35)
                                : Color(red: 1, green: 0.27, blue: 0.23))
                    }
                }
                if let stack = entry.holdingsValue {
                    Text("Your stack · $\(Int(stack).formatted())")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                } else {
                    Text(entry.price.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(intent: RefreshBTCIntent()) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

struct LargeWidgetView: View {
    let entry: PriceEntry
    private var changeColor: Color {
        guard let c = entry.change24h else { return .secondary }
        return c >= 0 ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 1, green: 0.27, blue: 0.23)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("Bitcoin")
                    .font(.headline)
                Spacer()
                Text(entry.price.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 8) {
                Text(entry.price.formatted)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if let change = entry.change24h {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(changeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10).fill(changeColor.opacity(0.12)))
                }
            }
            if let stack = entry.holdingsValue {
                Spacer()
                VStack(spacing: 2) {
                    Text("YOUR STACK")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    Text("$\(Int(stack).formatted())")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("TapBTC · Live Price")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .containerBackground(.background, for: .widget)
    }
}

// Lock Screen / StandBy widgets
struct AccessoryWidgetView: View {
    let entry: PriceEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.caption2)
                Text(entry.price.shortFormatted)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .widgetAccentable()
        case .accessoryInline:
            Text("BTC \(entry.price.shortFormatted)")
                .widgetAccentable()
        default: // .accessoryRectangular
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.price.formatted)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if let stack = entry.holdingsValue {
                        Text("Stack $\(Int(stack).formatted())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    } else {
                        Text(entry.price.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct BTCPriceWidget: Widget {
    let kind = "BitcoinWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BitcoinProvider()) { entry in
            BitcoinWidgetView(entry: entry)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live BTC price — refreshes every ~10 minutes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

@main
struct BitcoinWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        BTCPriceWidget()
        BTCLiveActivityWidget()
    }
}
