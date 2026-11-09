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
            // One entry, same as before the age-label fix. A tap runs
            // RefreshBTCIntent, which calls reloadAllTimelines(). watchOS only
            // replaces the visible complication when the current timeline does
            // not already cover the future. The per-minute / hourly / daily
            // entries added for the compact age kept serving that cached price,
            // so the reload never showed up. The age string is still measured
            // text (so "10m" / "10h" / "10d" scale instead of clipping); it
            // updates on this reload rather than on a prebuilt timeline.
            let entry = WatchBTCEntry(date: Date(), price: price, isFetching: false)
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
                    // Not `Text(_:style: .relative)`. That label is measured once
                    // and then updated in place, trailing-anchored, so the extra
                    // digit in "10m" / "10h" / "10d" draws past the leading edge
                    // and the circular mask clips it. `minimumScaleFactor` never
                    // runs again. A plain string is measured at its real width.
                    Text(compactComplicationAge(from: price.timestamp, to: entry.date))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
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
            // One measured string. A live relative date grows in place, and on
            // this single line that extra digit is what gets cut off.
            Text("\(price.formatted) · \(compactComplicationAge(from: price.timestamp, to: entry.date))")
        } else {
            Text("BTC ---")
        }
    }
}

struct CornerView: View {
    let entry: WatchBTCEntry
    var body: some View {
        Text(entry.price?.circularFormatted ?? "---")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .widgetLabel {
                if let price = entry.price {
                    // Curved corner text is just as tight as the circle, and the
                    // live relative date clips the same way once it gains a digit.
                    Text(compactComplicationAge(from: price.timestamp, to: entry.date))
                        .widgetAccentable()
                } else {
                    Text("TapBTC")
                        .widgetAccentable()
                }
            }
    }
}

/// Compact price age for the tight complication slots: "now", "9m", "10m", "23h", "10d".
private func compactComplicationAge(from timestamp: Date, to now: Date) -> String {
    let minutes = Int(max(0, now.timeIntervalSince(timestamp)) / 60)
    if minutes < 1 { return "now" }
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    return "\(hours / 24)d"
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
