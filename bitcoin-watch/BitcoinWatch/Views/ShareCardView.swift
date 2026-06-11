import SwiftUI
import Charts

struct ShareCardView: View {
    let price: BitcoinPrice
    let change24h: Double?
    let chartPrices: [Double]

    private let upColor   = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let downColor = Color(red: 1.00, green: 0.27, blue: 0.23)

    private var isUp: Bool { (change24h ?? 0) >= 0 }
    private var changeColor: Color { isUp ? upColor : downColor }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.14, blue: 0.13),
                         Color(red: 0.08, green: 0.07, blue: 0.07),
                         Color(red: 0.03, green: 0.02, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Orange left accent
            Rectangle()
                .fill(LinearGradient(colors: [.orange, .orange.opacity(0.3)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
                .padding(.vertical, 16)

            VStack(spacing: 0) {
                // ─── Two-column body ─────────────────────────────
                HStack(alignment: .top, spacing: 0) {

                    // LEFT: label + big price + badge
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 12))
                            Text("BTC / USD")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(price.formatted)
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.45)
                            .lineLimit(1)
                        if let change = change24h {
                            Text(String(format: "%+.2f%%", change))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(changeColor)
                                .padding(.horizontal, 9).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 7)
                                    .fill(changeColor.opacity(0.15)))
                                .padding(.top, 7)
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // RIGHT: chart header + sparkline
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 5) {
                            Text("24H")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Circle().fill(upColor).frame(width: 5, height: 5)
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(upColor)
                            }
                            Text("TapBTC")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                        sparkline
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                    .frame(width: 164)
                }

                // ─── Rule ──────────────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // ─── Footer ────────────────────────────────────
                HStack {
                    appStoreBadge
                    Spacer()
                    Text(price.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 375, height: 205)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var sparkline: some View {
        if chartPrices.isEmpty {
            Rectangle().fill(.clear).frame(width: 148, height: 82)
        } else {
            Chart {
                ForEach(Array(chartPrices.enumerated()), id: \.offset) { i, p in
                    LineMark(x: .value("T", i), y: .value("P", p))
                        .foregroundStyle(upColor)
                        .lineStyle(StrokeStyle(lineWidth: 1.8))
                    AreaMark(x: .value("T", i), y: .value("P", p))
                        .foregroundStyle(LinearGradient(
                            colors: [upColor.opacity(0.28), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                }
                if let lastIdx = chartPrices.indices.last {
                    PointMark(
                        x: .value("T", lastIdx),
                        y: .value("P", chartPrices[lastIdx])
                    )
                    .foregroundStyle(upColor)
                    .symbolSize(40)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(width: 148, height: 82)
        }
    }

    private var appStoreBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.logo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: -1) {
                Text("Download on the")
                    .font(.system(size: 7.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                Text("App Store")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 9))
    }
}

#if DEBUG
private let previewPrices: [Double] = [
    103_420, 103_890, 104_230, 104_050, 103_780, 104_510,
    104_890, 105_230, 104_980, 105_670, 106_120, 105_890,
    106_340, 106_780, 107_050, 106_820, 107_180, 107_420,
    107_090, 106_940, 107_310, 107_580, 107_240, 107_324
]

#Preview {
    ShareCardView(
        price: BitcoinPrice(usd: 107_324.50, timestamp: Date()),
        change24h: 3.47,
        chartPrices: previewPrices
    )
    .padding()
    .background(Color.black)
}
#endif
