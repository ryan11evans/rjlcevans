import SwiftUI
import Charts

struct PriceChartView: View {
    let history: [BitcoinPrice]

    private var minPrice: Double { history.map(\.usd).min() ?? 0 }
    private var maxPrice: Double { history.map(\.usd).max() ?? 1 }
    private var priceChange: Double? {
        guard let first = history.first?.usd, let last = history.last?.usd else { return nil }
        return last - first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let change = priceChange {
                HStack {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%+.2f", change))
                    Text("(last \(history.count) readings)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .foregroundStyle(change >= 0 ? .green : .red)
            }

            Chart(history, id: \.timestamp) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Price", point.usd)
                )
                .foregroundStyle(lineColor)
                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Min", minPrice),
                    yEnd: .value("Price", point.usd)
                )
                .foregroundStyle(lineColor.opacity(0.15))
            }
            .chartYScale(domain: (minPrice * 0.999)...(maxPrice * 1.001))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(shortFormat(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 160)
        }
    }

    private var lineColor: Color {
        guard let change = priceChange else { return .orange }
        return change >= 0 ? .green : .red
    }

    private func shortFormat(_ v: Double) -> String {
        v >= 1000 ? String(format: "$%.0fK", v / 1000) : String(format: "$%.0f", v)
    }
}
