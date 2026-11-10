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
            // One entry, same shape as 3.8. A tap's reloadAllTimelines()
            // replaces whatever timeline getTimeline completes with. The age
            // counts on its own (Text date style); future entries are not
            // required, and a week of them is what the 3.8.1 tap stopped on.
            let entry = WatchBTCEntry(date: Date(), price: price, isFetching: false)
            let next = Date(timeIntervalSinceNow: 15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchPrice() async -> BitcoinPrice? {
        // Same currency as the tap intent. A hardcoded BTC-USD fetch here would
        // overwrite a EUR/GBP/JPY price on every scheduled reload, and again
        // on the reload that follows a correct tap.
        let code = AppCurrency.current.code
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-\(code)/spot"),
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
                    CircularAgeLabel(date: price.timestamp)
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
                // Wider than the circle: this row has room, so the age stays
                // at 13pt instead of scaling down.
                CircularAgeLabel(date: price.timestamp, size: 13, width: 72, color: .tertiary, alignment: .leading)
            }
        }
        .font(.caption2)
    }
}

struct InlineView: View {
    let entry: WatchBTCEntry
    var body: some View {
        if let price = entry.price {
            // Compact price ("$150.0K") plus a live age held to a fixed width,
            // so "$150,000 · 10 minutes" cannot run off the inline slot.
            HStack(spacing: 3) {
                Text(price.shortFormatted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("·")
                    .foregroundStyle(.secondary)
                CircularAgeLabel(date: price.timestamp, width: 52)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
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
                    // Same 12pt / 32pt label as the circular face.
                    CircularAgeLabel(date: price.timestamp)
                        .widgetAccentable()
                } else {
                    Text("TapBTC")
                        .widgetAccentable()
                }
            }
    }
}

/// Live "how long since refresh" label.
///
/// Relative date text is archived at one width. A 0.5 scale floor was shrinking
/// it to fit a long reserved string inside 26pt, so "12m" became unreadably
/// small. 12pt semibold in 32pt fits "10m"…"59m" and "1h"/"2h" at full size
/// (monospaced digits, about 24pt wide) and still sits inside the bottom chord
/// on a 40/41mm watch. It may scale only to 0.85, never to half size.
private struct CircularAgeLabel: View {
    let date: Date
    var size: CGFloat = 12
    var width: CGFloat = 32
    var color: Color = .secondary
    var alignment: Alignment = .center

    var body: some View {
        Text(date, style: .relative)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .foregroundStyle(color)
            .frame(width: width, alignment: alignment)
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
        .description("Tap to refresh. Shows the live Bitcoin price.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}
