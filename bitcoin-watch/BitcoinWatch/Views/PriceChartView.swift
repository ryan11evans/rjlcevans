import SwiftUI

struct BitcoinInfoView: View {
    let stats: BitcoinStats?
    let currentPrice: Double?
    var chartLow: Double? = nil
    var chartHigh: Double? = nil
    var fearGreed: StatsService.FearGreedData? = nil

    var body: some View {
        VStack(spacing: 6) {
            BTCHeroAnimation()

            VStack(spacing: 8) {
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
                             color: .purple,
                             compact: true)
                    StatTile(label: "Fear & Greed",
                             value: fearGreed.map { "\($0.value) · \($0.classification)" } ?? "—",
                             subtitle: nil,
                             color: fearGreed.map { fearGreedColor($0.value) } ?? .gray,
                             compact: true)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 4)
    }

    private func high24h(_ s: BitcoinStats) -> Double {
        [currentPrice, chartHigh].compactMap { $0 }.max() ?? s.high24h
    }
    private func low24h(_ s: BitcoinStats) -> Double {
        [currentPrice, chartLow].compactMap { $0 }.min() ?? s.low24h
    }

    private func shortPrice(_ v: Double) -> String { AppCurrency.current.format(v) }

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

// Full-width animated Bitcoin hero: the classic coin + orbit arrows in the
// center, plus satellite mini-coins sweeping wide elliptical orbits across the
// whole strip and a drifting field of twinkling "sats" particles.
// Everything is driven by TimelineView time math (no repeatForever state), so
// it can't drift off-center and stays cheap to render.
private struct BTCHeroAnimation: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                SatsField(t: t)

                // Breathing outer glow
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .scaleEffect(1.2 + 0.12 * sin(t * 1.3))

                // Orange coin
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
                Text("₿")
                    .font(.system(size: 45, weight: .bold))
                    .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.02))
                // Orbit arrows: one revolution every 6 seconds
                OrbitArrows()
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(t * 60))
            }
        }
        .frame(height: 108)
        .frame(maxWidth: .infinity)
    }
}

// Canvas layer: twinkling sats dust + satellite mini-coins on wide ellipses.
private struct SatsField: View {
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2

            // Drifting "sats" dust across the full width
            for i in 0..<16 {
                let fi = Double(i)
                let seedX = pseudo(fi * 12.9898)
                let seedY = pseudo(fi * 78.233)
                let speed = 4 + 4 * pseudo(fi * 3.7)  // pt/sec sideways drift
                var x = (seedX * size.width + t * speed).truncatingRemainder(dividingBy: size.width + 20)
                if x < 0 { x += size.width + 20 }
                x -= 10
                let y = (0.1 + 0.8 * seedY) * size.height
                let twinkle = 0.10 + 0.35 * (0.5 + 0.5 * sin(t * (0.7 + seedY) + fi * 2.4))
                let r = 1.0 + 1.5 * pseudo(fi * 9.1)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(.orange.opacity(twinkle)))
            }

            // Satellite mini-coins: wide elliptical orbits with depth.
            // depth 1 = front (big, bright), 0 = back (small, dim). They fade
            // out as they pass behind the central coin.
            let a = cx - 14  // semi-major axis: nearly full width
            let orbits: [(b: CGFloat, period: Double, phase: Double, size: CGFloat)] = [
                (36, 11, 0.0, 9),
                (48, 17, 2.4, 7.5),
                (28, 8, 4.2, 6),
            ]
            for o in orbits {
                let ang = t * 2 * .pi / o.period + o.phase
                let x = cx + a * cos(ang)
                let y = cy + o.b * sin(ang)
                let depth = 0.5 + 0.5 * sin(ang)

                // Smoothly fade behind the central coin (84pt wide → r 42)
                var occlusion = 1.0
                if depth < 0.5 {
                    occlusion = min(1, max(0, (abs(x - cx) - 44) / 18))
                }
                guard occlusion > 0.01 else { continue }

                let s = o.size * (0.6 + 0.5 * depth)
                let opacity = (0.30 + 0.60 * depth) * occlusion

                // Soft glow
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                         with: .color(.orange.opacity(opacity * 0.22)))
                // Coin body
                ctx.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                         with: .color(.orange.opacity(opacity)))
                // Tiny ₿ on each satellite
                let glyph = Text("₿")
                    .font(.system(size: s * 0.95, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.75 * opacity))
                ctx.draw(ctx.resolve(glyph), at: CGPoint(x: x, y: y))
            }
        }
        .allowsHitTesting(false)
    }

    // Deterministic 0..1 pseudo-random from a seed — stable across frames.
    private func pseudo(_ x: Double) -> Double {
        let s = sin(x) * 43758.5453
        return s - s.rounded(.down)
    }
}

// Two comet trails chasing each other around the coin: each arc fades from a
// transparent tail up to a bright glowing head, with a soft under-glow so the
// ring feels lit rather than drawn.
private struct OrbitArrows: View {
    var body: some View {
        ZStack {
            comet
            comet.rotationEffect(.degrees(180))
        }
    }

    // One comet: trail from 0°(clear) → 140°(bright), head dot at 140°.
    private var comet: some View {
        ZStack {
            // Under-glow (wider, blurred)
            trailArc
                .stroke(
                    trailGradient(maxOpacity: 0.55),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .blur(radius: 4)

            // Core trail
            trailArc
                .stroke(
                    trailGradient(maxOpacity: 1.0),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

            // Glowing head
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 9, height: 9)
                    .blur(radius: 4)
                Circle()
                    .fill(
                        RadialGradient(colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.75),
                            Color(red: 0.98, green: 0.65, blue: 0.15)
                        ], center: .center, startRadius: 0, endRadius: 3.5)
                    )
                    .frame(width: 6.5, height: 6.5)
            }
            .offset(x: 50)                    // radius of the 100pt frame
            .rotationEffect(.degrees(140))    // sit at the arc's bright end
        }
    }

    // Arc covering 0°→140°, matching the gradient sweep below.
    private var trailArc: some Shape {
        Circle().trim(from: 0, to: 140.0 / 360.0)
    }

    private func trailGradient(maxOpacity: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .orange.opacity(0), location: 0),
                .init(color: .orange.opacity(0.30 * maxOpacity), location: 0.20),
                .init(color: .orange.opacity(maxOpacity), location: 140.0 / 360.0),
                .init(color: .orange.opacity(0), location: 0.40),
            ]),
            center: .center
        )
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
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 3) {
            Text(label)
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(compact
                      ? .system(size: 16, weight: .bold, design: .rounded)
                      : .system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: compact ? 9 : 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if !compact {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 8 : 12)
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
