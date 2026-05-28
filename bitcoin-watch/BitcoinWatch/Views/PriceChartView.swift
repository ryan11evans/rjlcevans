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
        v >= 1000 ? String(format: "$%.0fK", v / 1000) : String(format: "$%.0f", v)
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
            Circle()
                .fill(.orange.opacity(0.08))
            Image(systemName: "bitcoinsign.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.orange)
                .padding(32)
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
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                // keep tile height consistent
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
