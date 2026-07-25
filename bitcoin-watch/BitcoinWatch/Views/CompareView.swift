import SwiftUI
import Charts

private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)
private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = CompareService.shared

    @State private var range: CompareRange = .oneYear
    @State private var enabled: Set<CompareAsset> = [.bitcoin, .gold, .sp500, .mstr]

    private var activeAssets: [CompareAsset] {
        CompareAsset.allCases.filter { enabled.contains($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                             Color(red: 0.05, green: 0.04, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("", selection: $range) {
                            ForEach(CompareRange.allCases, id: \.self) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)

                        assetChips

                        chartCard

                        returnSummary
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Bitcoin vs. Everything")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .preferredColorScheme(.dark)
            .task(id: range) { await service.fetch(assets: CompareAsset.allCases, range: range) }
        }
    }

    private var assetChips: some View {
        HStack(spacing: 10) {
            ForEach(CompareAsset.allCases.filter { $0 != .bitcoin }) { asset in
                let isOn = enabled.contains(asset)
                Button {
                    if isOn { enabled.remove(asset) } else { enabled.insert(asset) }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(asset.color).frame(width: 8, height: 8)
                        Text(asset.displayName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isOn ? asset.color.opacity(0.15) : Color.white.opacity(0.06))
                    )
                }
            }
        }
    }

    @ViewBuilder private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("% RETURN")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)

            if service.isLoading && service.seriesByAsset.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else {
                Chart {
                    ForEach(activeAssets) { asset in
                        if let points = service.seriesByAsset[asset] {
                            ForEach(points) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Return", point.pctChange)
                                )
                                .foregroundStyle(by: .value("Asset", asset.displayName))
                                .lineStyle(StrokeStyle(lineWidth: asset == .bitcoin ? 2.5 : 1.5))
                                .interpolationMethod(.monotone)
                            }
                        }
                    }
                    RuleMark(y: .value("Break-even", 0))
                        .foregroundStyle(.white.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartForegroundStyleScale(
                    domain: activeAssets.map(\.displayName),
                    range: activeAssets.map(\.color)
                )
                .chartLegend(.hidden)
                .frame(minHeight: 220)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.08))
                        if let pct = value.as(Double.self) {
                            AxisValueLabel("\(pct >= 0 ? "+" : "")\(Int(pct))%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    @ViewBuilder private var returnSummary: some View {
        VStack(spacing: 0) {
            ForEach(Array(activeAssets.enumerated()), id: \.element) { index, asset in
                if index > 0 { Divider().padding(.leading, 44) }
                summaryRow(asset)
            }
        }
        .glassCard(cornerRadius: 18)
    }

    private func summaryRow(_ asset: CompareAsset) -> some View {
        HStack(spacing: 12) {
            Circle().fill(asset.color).frame(width: 10, height: 10)
            Text(asset.displayName)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if let pct = service.seriesByAsset[asset]?.last?.pctChange {
                Text("\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(pct >= 0 ? upColor : downColor)
            } else if service.errorAssets.contains(asset) {
                Text("Unavailable").font(.system(size: 12)).foregroundStyle(.tertiary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
