import SwiftUI

struct BitcoinInfoView: View {
    let stats: BitcoinStats?

    var body: some View {
        VStack(spacing: 24) {
            BTCOrbitLogo()
                .frame(width: 160, height: 160)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatTile(label: "24h High",
                             value: stats.map { shortPrice($0.high24h) } ?? "—",
                             subtitle: nil,
                             color: .green)
                    StatTile(label: "24h Low",
                             value: stats.map { shortPrice($0.low24h) } ?? "—",
                             subtitle: nil,
                             color: .red)
                }
                HStack(spacing: 10) {
                    StatTile(label: "All-Time High",
                             value: stats.map { shortPrice($0.ath) } ?? "—",
                             subtitle: stats.map { athDateString($0.athDate) },
                             color: .orange)
                    StatTile(label: "Block Height",
                             value: stats.map { "#\($0.blockHeight.formatted())" } ?? "—",
                             subtitle: nil,
                             color: .cyan)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private func shortPrice(_ v: Double) -> String {
        "$\(Int(v).formatted())"
    }

    private func athDateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }
}

// Animated ₿ with two orbiting arc-arrows
private struct BTCOrbitLogo: View {
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(.orange.opacity(0.12))
                .blur(radius: 18)
                .scaleEffect(1.3)
            // Coin
            Circle()
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.98, green: 0.70, blue: 0.28),
                        Color(red: 0.97, green: 0.58, blue: 0.10),
                        Color(red: 0.89, green: 0.50, blue: 0.04)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .overlay(Circle().strokeBorder(Color(red: 0.79, green: 0.43, blue: 0.02).opacity(0.6), lineWidth: 2))
            Image(systemName: "bitcoinsign.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.02))
                .padding(28)
            OrbitArrows()
                .rotationEffect(.degrees(angle))
                .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: angle)
                .onAppear { angle = 360 }
        }
    }
}

private struct OrbitArrows: View {
    var body: some View {
        ZStack {
            ArcArrow(startAngle: -60, endAngle: 60)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ArcArrowhead(angle: 60)
                .fill(.orange)
            ArcArrow(startAngle: 120, endAngle: 240)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ArcArrowhead(angle: 240)
                .fill(.orange)
        }
    }
}

private struct ArcArrow: Shape {
    let startAngle, endAngle: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: .degrees(startAngle), endAngle: .degrees(endAngle),
                 clockwise: false)
        return p
    }
}

private struct ArcArrowhead: Shape {
    let angle: Double
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let rad = angle * .pi / 180
        let tip  = CGPoint(x: rect.midX + r * cos(rad), y: rect.midY + r * sin(rad))
        let tang = rad + .pi / 2
        let size: CGFloat = 8
        let l = CGPoint(x: tip.x + size * cos(tang - 0.5), y: tip.y + size * sin(tang - 0.5))
        let ri = CGPoint(x: tip.x + size * cos(tang + 0.5), y: tip.y + size * sin(tang + 0.5))
        var p = Path(); p.move(to: tip); p.addLine(to: l); p.addLine(to: ri); p.closeSubpath()
        return p
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let subtitle: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(subtitle ?? " ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
