import SwiftUI
import Charts

struct BTCChartView: View {
    @ObservedObject var statsService: StatsService
    @State private var selectedDate: Date? = nil

    private var data: [StatsService.ChartPoint] { statsService.chartData }

    private var isUp: Bool {
        guard let first = data.first?.price, let last = data.last?.price else { return true }
        return last >= first
    }

    private var lineColor: Color {
        isUp ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 1, green: 0.27, blue: 0.23)
    }

    private var minPrice: Double { (data.map(\.price).min() ?? 0) * 0.9995 }
    private var maxPrice: Double { (data.map(\.price).max() ?? 100_000) * 1.0005 }

    private var selectedPoint: StatsService.ChartPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price History")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                    if let point = selectedPoint {
                        Text(BitcoinPrice(usd: point.price, timestamp: point.date).formatted)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        Text(point.date, style: .time)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: selectedPoint?.id)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(StatsService.ChartRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            Task { await statsService.fetchChart(range: range) }
                        }
                        .font(.system(size: 11, weight: statsService.chartRange == range ? .bold : .regular))
                        .foregroundStyle(statsService.chartRange == range ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            statsService.chartRange == range ?
                            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.12)) : nil
                        )
                    }
                }
            }

            if data.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.04))
                    .frame(height: 140)
                    .overlay(ProgressView().tint(.orange))
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Price", point.price)
                        )
                        .foregroundStyle(lineColor)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", point.date),
                            yStart: .value("Base", minPrice),
                            yEnd: .value("Price", point.price)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [lineColor.opacity(0.25), lineColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    if let selected = selectedPoint {
                        RuleMark(x: .value("Selected", selected.date))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        PointMark(
                            x: .value("Time", selected.date),
                            y: .value("Price", selected.price)
                        )
                        .foregroundStyle(lineColor)
                        .symbolSize(55)
                    }
                }
                .chartYScale(domain: minPrice...maxPrice)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXSelection(value: $selectedDate)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        )
    }
}
