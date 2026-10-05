import SwiftUI
import Foundation

struct RoundNumberProgressView: View {
    let price: Double

    // Round-number milestones generated algorithmically (1/1.5/2/2.5/3/4/5/6/
    // 7/7.5/8/9 × each power of ten) rather than a fixed USD table — a fixed
    // table topping out at 1,000,000 is wrong for JPY (BTC already trades at
    // ¥15-20M) and would eventually go stale for every currency once BTC's
    // price crosses its top rung.
    private var milestones: [Double] {
        let multipliers: [Double] = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 7.5, 8, 9]
        let topExponent = max(6, Int(floor(log10(max(price, 1)))) + 2)
        var result: [Double] = []
        for exponent in 2...topExponent {
            let base = pow(10.0, Double(exponent))
            result.append(contentsOf: multipliers.map { $0 * base })
        }
        return result
    }

    private var prev: Double { milestones.last  { $0 <  price } ?? milestones.first! }
    private var next: Double { milestones.first { $0 >= price } ?? milestones.last!  }
    private var progress: Double { next > prev ? (price - prev) / (next - prev) : 1 }
    private var away: Double { max(next - price, 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEXT MILESTONE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 10) {
                HStack {
                    Text(milestoneLabel(prev))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(milestoneLabel(next))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(colors: [Color.orange.opacity(0.7), .orange],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * CGFloat(progress)), height: 8)
                            .animation(.easeOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(String(format: "%.0f%% of the way", progress * 100))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(AppCurrency.current.format(away)) away")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func milestoneLabel(_ v: Double) -> String {
        let s = AppCurrency.current.symbol
        if v >= 1_000_000 { return "\(s)\(Int(v / 1_000_000))M" }
        return "\(s)\(Int(v / 1_000))K"
    }
}

#if DEBUG
#Preview {
    RoundNumberProgressView(price: 96_420)
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
#endif
