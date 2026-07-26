import SwiftUI

private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)

struct HalvingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var statsService = StatsService.shared
    let currentPrice: Double?

    private struct Event: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let blockHeight: Int
        let priceAtHalving: Double
        let subsidyBefore: Double
        let subsidyAfter: Double
    }

    // Historical facts — dates, block heights, and the price at each halving
    // are fixed forever, so these are recorded directly rather than re-derived
    // from a live fetch (Yahoo's BTC-USD history doesn't reach back to 2012 anyway).
    private let history: [Event] = [
        Event(label: "1st Halving", date: Self.date("2012-11-28"), blockHeight: 210_000,
              priceAtHalving: 12.35, subsidyBefore: 50, subsidyAfter: 25),
        Event(label: "2nd Halving", date: Self.date("2016-07-09"), blockHeight: 420_000,
              priceAtHalving: 650.63, subsidyBefore: 25, subsidyAfter: 12.5),
        Event(label: "3rd Halving", date: Self.date("2020-05-11"), blockHeight: 630_000,
              priceAtHalving: 8_821.42, subsidyBefore: 12.5, subsidyAfter: 6.25),
        Event(label: "4th Halving", date: Self.date("2024-04-20"), blockHeight: 840_000,
              priceAtHalving: 63_864.66, subsidyBefore: 6.25, subsidyAfter: 3.125),
    ]

    private static func date(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso) ?? Date()
    }

    // The historical dates above are calendar days, not instants — format them
    // in UTC so a device west of Greenwich doesn't roll them back a day.
    private static func displayDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                             Color(red: 0.05, green: 0.04, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        headline

                        if let blockHeight = statsService.stats?.blockHeight {
                            countdownCard(blockHeight)
                        }

                        ForEach(history) { event in
                            historyCard(event)
                        }

                        aboutCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Halving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var headline: some View {
        VStack(spacing: 4) {
            Text("⛏️").font(.system(size: 36))
            Text("The Halving").font(.system(size: 22, weight: .bold, design: .rounded))
            Text("Bitcoin's supply schedule, cut in half every 210,000 blocks")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 6)
    }

    private func countdownCard(_ blockHeight: Int) -> some View {
        let next = ((blockHeight / 210_000) + 1) * 210_000
        let blocksLeft = next - blockHeight
        let days = Double(blocksLeft) * 10 / (60 * 24)
        let countdown = days < 1 ? "< 1 day"
            : days < 365 ? "~\(Int(days)) days"
            : String(format: "~%.1f years", days / 365.25)

        return VStack(spacing: 10) {
            Text("NEXT HALVING")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            Text(countdown)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
            Text("Block #\(next.formatted()) · \(blocksLeft.formatted()) blocks left")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard(cornerRadius: 18)
    }

    private func historyCard(_ event: Event) -> some View {
        let pctSinceHalving = currentPrice.map { ($0 / event.priceAtHalving - 1) * 100 }

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary).tracking(0.4)
                Text(Self.displayDate(event.date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Block #\(event.blockHeight.formatted()) · \(event.subsidyBefore.formatted())→\(event.subsidyAfter.formatted()) BTC")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("BTC was \(AppCurrency.current.format(event.priceAtHalving))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if let pct = pctSinceHalving {
                    Text("\(pct >= 0 ? "+" : "")\(pct.formatted(.number.precision(.fractionLength(0))))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(pct >= 0 ? upColor : Color(red: 1, green: 0.27, blue: 0.23))
                    Text("since").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, shadow: false)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                Text("Why it matters").font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Text("Every 210,000 blocks (~4 years), the reward miners earn for adding a new block is cut in half. That's the only way new bitcoin enters circulation — so a halving directly slows the pace of new supply. Total supply is capped at 21 million BTC, reached around the year 2140.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16, shadow: false)
    }
}

#if DEBUG
#Preview {
    HalvingView(currentPrice: 96_420)
}
#endif
