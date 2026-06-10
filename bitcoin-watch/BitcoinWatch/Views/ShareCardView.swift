import SwiftUI

private let appStoreURLString = "https://apps.apple.com/us/app/tapbtc/id6774023419"

struct ShareCardView: View {
    let price: BitcoinPrice
    let change24h: Double?
    let high24h: Double?
    let low24h: Double?

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

            // Orange left accent bar
            Rectangle()
                .fill(
                    LinearGradient(colors: [.orange, .orange.opacity(0.4)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 3)
                .padding(.vertical, 16)
                .padding(.leading, 0)

            VStack(alignment: .leading, spacing: 0) {

                // ── Header ──────────────────────────────────────
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 13))
                        Text("BTC / USD")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Circle()
                            .fill(upColor)
                            .frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(upColor)
                        Text("·")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 8))
                        Text("TapBTC")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // ── Price + change ───────────────────────────────
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(price.formatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer()
                    if let change = change24h {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(changeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(changeColor.opacity(0.15))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 7)

                // ── Rule ────────────────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 11)

                // ── 24h High / Low ───────────────────────────────
                HStack(spacing: 16) {
                    if let high = high24h {
                        StatPill(
                            icon: "arrow.up",
                            label: "24H HIGH",
                            value: priceFmt(high),
                            color: upColor
                        )
                    }
                    if high24h != nil && low24h != nil {
                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 1, height: 26)
                    }
                    if let low = low24h {
                        StatPill(
                            icon: "arrow.down",
                            label: "24H LOW",
                            value: priceFmt(low),
                            color: downColor
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // ── Rule ────────────────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                // ── Footer ──────────────────────────────────────
                HStack {
                    // App Store badge
                    HStack(spacing: 5) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: -1) {
                            Text("Download on the")
                                .font(.system(size: 7, weight: .regular))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("App Store")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Text(price.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 9)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 340, height: 182)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func priceFmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

// UIKit share sheet wrapper
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#if DEBUG
#Preview {
    ShareCardView(
        price: BitcoinPrice(usd: 107_324.50, timestamp: Date()),
        change24h: 3.47,
        high24h: 109_150,
        low24h: 103_420
    )
    .padding()
    .background(Color.black)
}
#endif
