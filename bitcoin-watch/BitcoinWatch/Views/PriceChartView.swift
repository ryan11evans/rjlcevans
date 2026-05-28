import SwiftUI

struct BitcoinInfoView: View {
    let history: [BitcoinPrice]

    private var sessionHigh: Double? { history.map(\.usd).max() }
    private var sessionLow:  Double? { history.map(\.usd).min() }
    private var sessionChange: Double? {
        guard let first = history.first?.usd, let last = history.last?.usd else { return nil }
        return ((last - first) / first) * 100
    }

    var body: some View {
        VStack(spacing: 28) {
            BTCOrbitLogo()
                .frame(width: 160, height: 160)

            if history.count > 1 {
                HStack(spacing: 12) {
                    StatTile(label: "Session High",
                             value: sessionHigh.map { formatPrice($0) } ?? "—",
                             color: .green)
                    StatTile(label: "Session Low",
                             value: sessionLow.map { formatPrice($0) } ?? "—",
                             color: .red)
                    StatTile(label: "Change",
                             value: sessionChange.map { String(format: "%+.2f%%", $0) } ?? "—",
                             color: (sessionChange ?? 0) >= 0 ? .green : .red)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func formatPrice(_ v: Double) -> String {
        v >= 1000 ? String(format: "$%.0fK", v / 1000) : String(format: "$%.0f", v)
    }
}

// Animated ₿ with two orbiting arc-arrows (matches the app icon theme)
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
            // Top-right arc arrow
            ArcArrow(startAngle: -60, endAngle: 60, clockwise: true)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ArcArrowhead(angle: 60, clockwise: true)
                .fill(.orange)

            // Bottom-left arc arrow
            ArcArrow(startAngle: 120, endAngle: 240, clockwise: true)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ArcArrowhead(angle: 240, clockwise: true)
                .fill(.orange)
        }
    }
}

private struct ArcArrow: Shape {
    let startAngle: Double
    let endAngle: Double
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width / 2,
                 startAngle: .degrees(startAngle),
                 endAngle: .degrees(endAngle),
                 clockwise: false)
        return p
    }
}

private struct ArcArrowhead: Shape {
    let angle: Double
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let cx = rect.midX
        let cy = rect.midY
        let rad = angle * .pi / 180
        let tip = CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
        let tangentAngle = rad + (clockwise ? .pi / 2 : -.pi / 2)
        let size: CGFloat = 8
        let left  = CGPoint(x: tip.x + size * cos(tangentAngle - 0.5),
                            y: tip.y + size * sin(tangentAngle - 0.5))
        let right = CGPoint(x: tip.x + size * cos(tangentAngle + 0.5),
                            y: tip.y + size * sin(tangentAngle + 0.5))
        var p = Path()
        p.move(to: tip)
        p.addLine(to: left)
        p.addLine(to: right)
        p.closeSubpath()
        return p
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
