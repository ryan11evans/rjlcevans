import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct WatchBTCEntry: TimelineEntry {
    let date: Date
    let price: BitcoinPrice?
    let isFetching: Bool
}

struct WatchBTCProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchBTCEntry {
        WatchBTCEntry(date: Date(), price: BitcoinPrice(usd: 65000, timestamp: Date()), isFetching: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchBTCEntry) -> Void) {
        completion(WatchBTCEntry(date: Date(), price: UserDefaults.shared.loadPrice(), isFetching: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchBTCEntry>) -> Void) {
        Task {
            let price = await fetchPrice() ?? UserDefaults.shared.loadPrice()
            let entry = WatchBTCEntry(date: Date(), price: price, isFetching: false)
            // Ask to be refreshed in 15 min — watchOS may extend this based on budget
            let next = Date(timeIntervalSinceNow: 15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchPrice() async -> BitcoinPrice? {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot"),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { struct D: Decodable { let amount: String }; let data: D }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let val = Double(r.data.amount) else { return nil }
        let price = BitcoinPrice(usd: val, timestamp: Date())
        UserDefaults.shared.savePrice(price)
        return price
    }
}

// MARK: - Views

// The whole complication is the button — one tap anywhere refreshes.
// On watchOS 10+, Button(intent:) runs the AppIntent without launching the app.
struct BTCComplicationView: View {
    let entry: WatchBTCEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Button(intent: RefreshBTCIntent()) {
            complicationContent
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var complicationContent: some View {
        switch family {
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        case .accessoryCorner:
            CornerView(entry: entry)
        default:
            CircularView(entry: entry)
        }
    }
}

struct CircularView: View {
    let entry: WatchBTCEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.price?.circularFormatted ?? "---")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .widgetAccentable()
                if let price = entry.price {
                    Text(price.timestamp, style: .relative)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "bitcoinsign")
                        .font(.system(size: 9, weight: .bold))
                        .widgetAccentable()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct RectangularView: View {
    let entry: WatchBTCEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .widgetAccentable()
                    .font(.caption2)
                Text("BITCOIN")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.price?.formatted ?? "---")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .widgetAccentable()
            }
            if let price = entry.price {
                Text(price.timestamp, style: .relative)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption2)
    }
}

struct InlineView: View {
    let entry: WatchBTCEntry
    var body: some View {
        if let price = entry.price {
            Text(price.formatted + " · ") + Text(price.timestamp, style: .relative)
        } else {
            Text("BTC ---")
        }
    }
}

struct CornerView: View {
    let entry: WatchBTCEntry
    var body: some View {
        Text(entry.price?.shortFormatted ?? "---")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .widgetLabel {
                if let price = entry.price {
                    Text(price.timestamp, style: .relative)
                        .widgetAccentable()
                } else {
                    Text("TapBTC")
                        .widgetAccentable()
                }
            }
    }
}

// MARK: - Widget Declaration

@main
struct BTCWatchComplicationBundle: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BTCWatchComplication", provider: WatchBTCProvider()) { entry in
            BTCComplicationView(entry: entry)
        }
        .configurationDisplayName("Bitcoin")
        .description("Tap to refresh. Shows live BTC/USD price.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
