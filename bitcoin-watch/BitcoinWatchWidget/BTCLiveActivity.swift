import ActivityKit
import WidgetKit
import SwiftUI

struct BTCLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BTCLiveActivityAttributes.self) { context in
            BTCLockScreenLiveView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("BITCOIN")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(BitcoinPrice(usd: context.state.price, timestamp: context.state.timestamp).formatted)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let change = context.state.change24h {
                            Text(String(format: "%+.2f%%", change))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(change >= 0
                                    ? Color(red: 0.19, green: 0.82, blue: 0.35)
                                    : Color(red: 1, green: 0.27, blue: 0.23))
                        }
                        Text(context.state.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("TapBTC · Live Bitcoin Price")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } compactLeading: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14, weight: .semibold))
            } compactTrailing: {
                Text(BitcoinPrice(usd: context.state.price, timestamp: context.state.timestamp).shortFormatted)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .widgetAccentable()
            } minimal: {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct BTCLockScreenLiveView: View {
    let state: BTCLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundStyle(.orange)
                .font(.title)

            VStack(alignment: .leading, spacing: 2) {
                Text("Bitcoin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(BitcoinPrice(usd: state.price, timestamp: state.timestamp).formatted)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let change = state.change24h {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(change >= 0
                            ? Color(red: 0.19, green: 0.82, blue: 0.35)
                            : Color(red: 1, green: 0.27, blue: 0.23))
                }
                Text(state.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
