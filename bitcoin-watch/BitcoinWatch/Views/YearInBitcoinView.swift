import SwiftUI
import LinkPresentation

private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)
private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

struct YearInBitcoinView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var holdings = HoldingsService.shared
    let currentPrice: Double?

    @State private var biggestGainDay: (date: Date, pct: Double)? = nil
    @State private var maxDrawdown: (date: Date, pct: Double)? = nil
    @State private var isLoadingHistory = true

    private var firstDate: Date? { holdings.purchases.map(\.date).min() }
    private var daysStacking: Int {
        guard let firstDate else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0)
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

                if firstDate == nil {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            headline
                            statCard(icon: "calendar", label: "STACKING SINCE",
                                     value: firstDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—",
                                     detail: "\(daysStacking) days and counting")

                            if let price = currentPrice, let gain = holdings.gain(at: price) {
                                statCard(icon: "chart.line.uptrend.xyaxis",
                                         label: "UNREALIZED RETURN",
                                         value: "\(gain.pct >= 0 ? "+" : "")\(String(format: "%.1f", gain.pct * 100))%",
                                         detail: "Avg cost \(holdings.avgCost.map { AppCurrency.current.format($0) } ?? "—") → now \(AppCurrency.current.format(price))",
                                         valueColor: gain.pct >= 0 ? upColor : downColor)
                            }

                            if holdings.hasSales, let pct = holdings.realizedPct {
                                statCard(icon: "checkmark.seal",
                                         label: "REALIZED P&L",
                                         value: "\(holdings.realizedGain >= 0 ? "+" : "-")\(AppCurrency.current.format(abs(holdings.realizedGain)))",
                                         detail: "\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct * 100))% on what you sold",
                                         valueColor: holdings.realizedGain >= 0 ? upColor : downColor)
                            }

                            statCard(icon: "bag", label: "ACTIVITY",
                                     value: "\(holdings.purchases.count)",
                                     detail: holdings.purchases.count == 1 ? "buy logged" : "buys logged"
                                        + (holdings.sales.isEmpty ? "" : " · \(holdings.sales.count) sell\(holdings.sales.count == 1 ? "" : "s")"))

                            if isLoadingHistory {
                                ProgressView().padding(.vertical, 20)
                            } else {
                                if let big = biggestGainDay {
                                    statCard(icon: "bolt.fill", label: "BIGGEST DAY YOU HELD THROUGH",
                                              value: "+\(String(format: "%.1f", big.pct))%",
                                              detail: big.date.formatted(date: .abbreviated, time: .omitted),
                                              valueColor: upColor)
                                }
                                if let dip = maxDrawdown {
                                    statCard(icon: "arrow.down.right", label: "DEEPEST DIP YOU HELD THROUGH",
                                              value: "\(String(format: "%.1f", dip.pct))%",
                                              detail: "from peak, around \(dip.date.formatted(date: .abbreviated, time: .omitted))",
                                              valueColor: downColor)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Your Year in Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if firstDate != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { renderAndShare() } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .task { await loadHistory() }
        }
    }

    private var headline: some View {
        VStack(spacing: 4) {
            Text("₿").font(.system(size: 40, weight: .bold)).foregroundStyle(.orange)
            Text("Your Stack's Story").font(.system(size: 22, weight: .bold, design: .rounded))
        }
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bitcoinsign.circle").font(.system(size: 44)).foregroundStyle(.orange)
            Text("No story yet").font(.system(size: 18, weight: .bold, design: .rounded))
            Text("Log your first buy in Your Holdings to start your recap.")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func statCard(icon: String, label: String, value: String, detail: String, valueColor: Color = .white) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary).tracking(0.4)
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                Text(detail)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 16, shadow: false)
    }

    // MARK: - History-derived stats

    private func loadHistory() async {
        defer { isLoadingHistory = false }
        guard let firstDate else { return }
        let daysSince = max(1, Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 1)
        let range: CompareRange = daysSince <= 370 ? .oneYear : (daysSince <= 1825 ? .fiveYear : .all)

        guard let raw = await CompareService.fetchRawCloses(asset: .bitcoin, range: range) else { return }
        let points = raw.filter { $0.date >= firstDate }.sorted { $0.date < $1.date }
        guard points.count > 1 else { return }

        var bestGain: (Date, Double)? = nil
        for i in 1..<points.count {
            let prev = points[i - 1].close
            guard prev > 0 else { continue }
            let pct = (points[i].close / prev - 1) * 100
            if bestGain == nil || pct > bestGain!.1 { bestGain = (points[i].date, pct) }
        }
        biggestGainDay = bestGain

        var peak = points[0].close
        var worstDrawdown: (Date, Double)? = nil
        for point in points {
            peak = max(peak, point.close)
            guard peak > 0 else { continue }
            let pct = (point.close / peak - 1) * 100
            if worstDrawdown == nil || pct < worstDrawdown!.1 { worstDrawdown = (point.date, pct) }
        }
        maxDrawdown = worstDrawdown
    }

    // MARK: - Share

    @MainActor
    private func renderAndShare() {
        let card = recapShareCard
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        let metadata = LPLinkMetadata()
        metadata.url = URL(string: "https://rjlcevans.com/tapbtc")
        metadata.title = "My Year in Bitcoin"
        metadata.imageProvider = NSItemProvider(object: image)
        let shareItem = BTCShareItem(metadata: metadata)

        var top = root
        while let next = top.presentedViewController { top = next }
        let vc = UIActivityViewController(activityItems: [shareItem], applicationActivities: nil)
        top.present(vc, animated: true)
    }

    private var recapShareCard: some View {
        VStack(spacing: 16) {
            Text("₿ My Year in Bitcoin").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.orange)
            if let firstDate {
                Text("Stacking since \(firstDate.formatted(date: .abbreviated, time: .omitted)) · \(daysStacking) days")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            if let price = currentPrice, let gain = holdings.gain(at: price) {
                VStack(spacing: 2) {
                    Text("\(gain.pct >= 0 ? "+" : "")\(String(format: "%.1f", gain.pct * 100))%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(gain.pct >= 0 ? upColor : downColor)
                    Text("unrealized return").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            if let big = biggestGainDay {
                Text("Biggest day: +\(String(format: "%.1f", big.pct))% on \(big.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 340)
        .background(Color(red: 0.07, green: 0.06, blue: 0.06))
        .environment(\.colorScheme, .dark)
    }
}
