import SwiftUI

struct RoundNumberProgressView: View {
    let price: Double

    private let milestones: [Double] = [
        10_000, 15_000, 20_000, 25_000, 30_000, 40_000, 50_000,
        60_000, 70_000, 75_000, 80_000, 90_000, 100_000, 110_000,
        120_000, 125_000, 150_000, 175_000, 200_000, 250_000,
        300_000, 400_000, 500_000, 750_000, 1_000_000
    ]

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
