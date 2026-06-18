import SwiftUI

struct BitcoinInfoView: View {
    let stats: BitcoinStats?
    let currentPrice: Double?
    var fearGreed: StatsService.FearGreedData? = nil

    var body: some View {
        VStack(spacing: 10) {
            BTCOrbitLogo()
                .frame(width: 100, height: 100)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    StatTile(label: "24h High",
                             value: stats.map { shortPrice(high24h($0)) } ?? "—",
                             subtitle: nil,
                             color: .green)
                    StatTile(label: "24h Low",
                             value: stats.map { shortPrice(low24h($0)) } ?? "—",
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
                HStack(spacing: 10) {
                    StatTile(label: "Next Halving",
                             value: stats.map { halvingCountdown($0.blockHeight) } ?? "—",
                             subtitle: stats.map { halvingSubtitle($0.blockHeight) },
                             color: .purple)
                    StatTile(label: "Fear & Greed",
                             value: fearGreed.map { "\($0.value)" } ?? "—",
                             subtitle: fearGreed?.classification,
                             color: fearGreed.map { fearGreedColor($0.value) } ?? .gray)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }

    private func high24h(_ s: BitcoinStats) -> Double { max(s.high24h, currentPrice ?? s.high24h) }
    private func low24h(_ s: BitcoinStats) -> Double  { min(s.low24h,  currentPrice ?? s.low24h) }

    private func shortPrice(_ v: Double) -> String { "$\(Int(v).formatted())" }

    private func athDateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: d)
    }

    private func fearGreedColor(_ value: Int) -> Color {
        switch value {
        case 0..<25:  return Color(red: 1, green: 0.27, blue: 0.23)
        case 25..<50: return .orange
        case 50..<75: return Color(red: 0.19, green: 0.82, blue: 0.35)
        default:      return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }

    private func halvingCountdown(_ blockHeight: Int) -> String {
        let next = ((blockHeight / 210_000) + 1) * 210_000
        let days = Double(next - blockHeight) * 10 / (60 * 24)
        if days < 1 { return "< 1 day" }
        if days < 365 { return "~\(Int(days)) days" }
        return String(format: "~%.1f yrs", days / 365.25)
    }

    private func halvingSubtitle(_ blockHeight: Int) -> String {
        let next = ((blockHeight / 210_000) + 1) * 210_000
        return "Block #\(next.formatted()) · \((next - blockHeight).formatted()) left"
    }
}

// Animated ₿ with two orbiting arc-arrows
private struct BTCOrbitLogo: View {
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(.orange.opacity(0.15))
                .blur(radius: 20)
                .scaleEffect(1.3)
            // Orange coin — explicitly smaller so the orbit sits outside it
            Circle()
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.98, green: 0.70, blue: 0.28),
                        Color(red: 0.97, green: 0.58, blue: 0.10),
                        Color(red: 0.89, green: 0.50, blue: 0.04)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .overlay(Circle().strokeBorder(Color(red: 0.79, green: 0.43, blue: 0.02).opacity(0.6), lineWidth: 2))
                .frame(width: 84, height: 84)
            // ₿ as text so it sits cleanly on top of the orange coin
            Text("₿")
                .font(.system(size: 45, weight: .bold))
                .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.02))
            // Orbit arrows fill the full 100×100 frame so arcs draw outside the 84pt coin
            OrbitArrows()
                .frame(width: 100, height: 100)
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

private struct FearGreedTile: View {
    let data: StatsService.FearGreedData

    private var color: Color {
        switch data.value {
        case 0..<25:  return Color(red: 1, green: 0.27, blue: 0.23)   // red
        case 25..<50: return .orange
        case 50..<75: return Color(red: 0.19, green: 0.82, blue: 0.35) // green
        default:      return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Gauge arc
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 56, height: 28)
                    .clipped()
                Circle()
                    .trim(from: 0, to: CGFloat(data.value) / 200)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: 56, height: 28)
                    .clipped()
                    .animation(.easeOut(duration: 0.6), value: data.value)
                Text("\(data.value)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .offset(y: 6)
            }
            .frame(width: 56, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Fear & Greed")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.3)
                Text(data.classification)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                Text("Updated daily · alternative.me")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
