import SwiftUI
import Charts

struct WatchContentView: View {
    @EnvironmentObject var service: WatchPriceService
    @StateObject private var stats = WatchStatsService.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        TabView {
            PricePage(service: service, change24h: stats.change24h)
            ChartPage(stats: stats, livePrice: service.currentPrice?.usd)
            StatsPage(stats: stats, livePrice: service.currentPrice?.usd,
                      holdingsValue: service.holdingsValue)
        }
        .tabViewStyle(.verticalPage)
        .task { await stats.fetchIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                service.startForegroundRefresh()
                Task { await stats.fetchIfNeeded() }
            } else {
                service.stopForegroundRefresh()
            }
        }
    }
}

// MARK: - Page 1: Price

private struct PricePage: View {
    @ObservedObject var service: WatchPriceService
    let change24h: Double?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                Text("BTC / USD")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let price = service.currentPrice {
                Text(price.shortFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let change = change24h {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(change >= 0
                            ? Color(red: 0.19, green: 0.82, blue: 0.35)
                            : Color(red: 1, green: 0.27, blue: 0.23))
                }

                if let stack = service.holdingsValue {
                    Text("Stack · $\(Int(stack).formatted())")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                } else {
                    Text(price.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if service.isLoading {
                ProgressView()
            } else {
                Text("---")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await service.fetchDirect() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(service.isLoading)
        }
    }
}

// MARK: - Page 2: Chart

private struct ChartPage: View {
    @ObservedObject var stats: WatchStatsService
    let livePrice: Double?

    private var points: [WatchStatsService.ChartPoint] {
        var p = stats.chartPoints
        if let live = livePrice {
            p.append(WatchStatsService.ChartPoint(date: Date(), price: live))
        }
        return p
    }

    private var isUp: Bool {
        guard let first = points.first?.price, let last = points.last?.price else { return true }
        return last >= first
    }

    private var lineColor: Color {
        isUp ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 1, green: 0.27, blue: 0.23)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("24H CHART")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if points.isEmpty {
                Spacer()
                ProgressView().tint(.orange)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                let lo = points.map(\.price).min() ?? 0
                let hi = points.map(\.price).max() ?? 1
                Chart(points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Price", point.price)
                    )
                    .foregroundStyle(lineColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", point.date),
                        yStart: .value("Base", lo),
                        yEnd: .value("Price", point.price)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [lineColor.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: lo...hi)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Page 3: Stats

private struct StatsPage: View {
    @ObservedObject var stats: WatchStatsService
    let livePrice: Double?
    var holdingsValue: Double? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let stack = holdingsValue {
                StatRow(label: "YOUR STACK",
                        value: "$\(Int(stack).formatted())",
                        color: .orange)
            }
            StatRow(label: "24H HIGH",
                    value: clampedHigh.map(shortPrice) ?? "—",
                    color: Color(red: 0.19, green: 0.82, blue: 0.35))
            StatRow(label: "24H LOW",
                    value: clampedLow.map(shortPrice) ?? "—",
                    color: Color(red: 1, green: 0.27, blue: 0.23))
            StatRow(label: "ATH",
                    value: stats.ath.map(shortPrice) ?? "—",
                    color: .orange)
            if holdingsValue == nil {
                StatRow(label: "BLOCK",
                        value: stats.blockHeight.map { "#\($0.formatted())" } ?? "—",
                        color: .cyan)
            }
        }
        .padding(.horizontal, 4)
    }

    private var clampedHigh: Double? {
        guard let h = stats.high24h else { return nil }
        return max(h, livePrice ?? h)
    }

    private var clampedLow: Double? {
        guard let l = stats.low24h else { return nil }
        return min(l, livePrice ?? l)
    }

    private func shortPrice(_ v: Double) -> String {
        "$\(Int(v).formatted())"
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}
