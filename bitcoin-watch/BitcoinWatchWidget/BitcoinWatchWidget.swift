import WidgetKit
import SwiftUI

// Timeline provider — iOS calls getTimeline() to schedule widget refreshes.
// We request the next update in 10 minutes; iOS may round up, but this gives
// the fastest widget refresh rate allowed without a server push (push = fastest,
// but requires a notification infrastructure).
struct BitcoinProvider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date(), price: BitcoinPrice(usd: 65000, timestamp: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        let price = UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 65000, timestamp: Date())
        completion(PriceEntry(date: Date(), price: price))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let price = await fetchLatestPrice() ?? UserDefaults.shared.loadPrice() ?? BitcoinPrice(usd: 0, timestamp: Date())
            let entry = PriceEntry(date: Date(), price: price)
            // Request refresh in 10 min — WidgetKit may defer, but this is the minimum ask
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
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
}

struct BitcoinWidgetView: View {
    let entry: PriceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:   SmallWidgetView(entry: entry)
        case .systemMedium:  MediumWidgetView(entry: entry)
        case .systemLarge:   MediumWidgetView(entry: entry)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            AccessoryWidgetView(entry: entry, family: family)
        default:             SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                Text("BTC")
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.price.shortFormatted)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(entry.price.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

struct MediumWidgetView: View {
    let entry: PriceEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("Bitcoin")
                        .font(.headline)
                }
                Text(entry.price.formatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(entry.price.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
                    Text(entry.price.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@main
struct BitcoinWatchWidget: Widget {
    let kind = "BitcoinWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BitcoinProvider()) { entry in
            BitcoinWidgetView(entry: entry)
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live BTC price — refreshes every ~10 minutes.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}
