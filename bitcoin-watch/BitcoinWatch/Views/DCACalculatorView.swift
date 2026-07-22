import SwiftUI
import LinkPresentation

// MARK: - Container shell

struct CalculatorsView: View {
    let currentPrice: Double?
    @State private var tab = 0
    @Environment(\.dismiss) private var dismiss

    private let titles = ["DCA Calculator", "Goal Tracker"]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                             Color(red: 0.05, green: 0.04, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $tab) {
                        Text("DCA").tag(0)
                        Text("Goal").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    TabView(selection: $tab) {
                        DCATab(currentPrice: currentPrice).tag(0)
                        GoalTab(currentPrice: currentPrice).tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(titles[tab])
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Shared helpers

fileprivate func lbl(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .tracking(0.5)
}

fileprivate func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(active ? .orange : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
        )
}

@MainActor
fileprivate func presentShare(_ item: BTCShareItem) {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first?.rootViewController else { return }
    var top = root
    while let next = top.presentedViewController { top = next }
    let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
    top.present(vc, animated: true)
}

fileprivate extension Double {
    var btcFormatted: String {
        if self >= 1     { return String(format: "%.4f BTC", self) }
        if self >= 0.001 { return String(format: "%.6f BTC", self) }
        return               String(format: "%.8f BTC", self)
    }
}

// MARK: - DCA Tab

private struct DCATab: View {
    let currentPrice: Double?
    @State private var amountText = "100"
    @State private var freq: Freq = .weekly

    enum Freq: String, CaseIterable {
        case daily = "Daily", weekly = "Weekly", monthly = "Monthly"
        var perYear: Double { switch self { case .daily: 365; case .weekly: 52; case .monthly: 12 } }
        var perLabel: String { switch self { case .daily: "day"; case .weekly: "week"; case .monthly: "month" } }
    }

    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private var btcPer: Double {
        guard let p = currentPrice, p > 0, amount > 0 else { return 0 }
        return amount / p
    }
    private let rows = [("1 Year", 1.0), ("2 Years", 2.0), ("5 Years", 5.0), ("10 Years", 10.0)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    lbl("INVEST PER PERIOD")
                    HStack(spacing: 8) {
                        Text(AppCurrency.current.symbol).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                        TextField("100", text: $amountText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 8) {
                    ForEach(["25", "50", "100", "500"], id: \.self) { v in
                        chip(v, active: amountText == v) { amountText = v }
                    }
                }

                // Frequency
                VStack(alignment: .leading, spacing: 8) {
                    lbl("FREQUENCY")
                    HStack(spacing: 0) {
                        ForEach(Freq.allCases, id: \.rawValue) { f in
                            Button(f.rawValue) { withAnimation(.easeInOut(duration: 0.15)) { freq = f } }
                                .font(.system(size: 14, weight: freq == f ? .semibold : .regular))
                                .foregroundStyle(freq == f ? .orange : .secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(freq == f ? Color.orange.opacity(0.15) : Color.clear)
                        }
                    }
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if amount > 0, let price = currentPrice, price > 0 {
                    // Per-purchase badge
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            lbl("PER PURCHASE")
                            Text(btcPer.btcFormatted)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange).minimumScaleFactor(0.6).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            lbl("BTC PRICE")
                            Text(BitcoinPrice(usd: price, timestamp: Date()).formatted)
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

                    // Projection table
                    VStack(alignment: .leading, spacing: 10) {
                        lbl("ACCUMULATION PROJECTION")
                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                                let btc = btcPer * freq.perYear * row.1
                                let inv = amount * freq.perYear * row.1
                                HStack {
                                    Text(row.0).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                                        .frame(width: 85, alignment: .leading)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(btc.btcFormatted)
                                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                                        Text("\(AppCurrency.current.format(inv)) in")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                .background(Color.white.opacity(idx % 2 == 0 ? 0.05 : 0.03))
                                if idx < rows.count - 1 {
                                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Share
                    Button { doShare() } label: {
                        Label("Share DCA Plan", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.top, 20).padding(.horizontal, 20)
        }
    }

    @MainActor private func doShare() {
        guard let price = currentPrice else { return }
        let card = DCAShareCard(amount: amount, freqLabel: freq.perLabel,
                                btcPer: btcPer, price: price,
                                rows: rows.map { (label: $0.0, btc: btcPer * freq.perYear * $0.1, invested: amount * freq.perYear * $0.1) })
            .environment(\.colorScheme, .dark)
        let r = ImageRenderer(content: card); r.scale = 3
        guard let img = r.uiImage else { return }
        let meta = LPLinkMetadata()
        meta.url = URL(string: "https://rjlcevans.com/tapbtc")
        meta.title = "I stack \(AppCurrency.current.symbol)\(Int(amount)) in Bitcoin every \(freq.perLabel) with TapBTC"
        meta.imageProvider = NSItemProvider(object: img)
        presentShare(BTCShareItem(metadata: meta))
    }
}

// MARK: - Goal Tracker Tab

private struct GoalTab: View {
    let currentPrice: Double?
    @AppStorage("goalTargetStr") private var targetStr = "1.0"
    @AppStorage("goalHeldStr")   private var heldStr   = "0"

    private var target: Double    { max(Double(targetStr) ?? 1, 0) }
    private var held: Double      { max(Double(heldStr) ?? 0, 0) }
    private var remaining: Double { max(target - held, 0) }
    private var progress: Double  { target > 0 ? min(held / target, 1) : 0 }

    private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Target input
                VStack(alignment: .leading, spacing: 8) {
                    lbl("MY TARGET")
                    HStack(spacing: 8) {
                        TextField("1.0", text: $targetStr)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad).foregroundStyle(.white)
                        Text("BTC").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 8) {
                    ForEach(["0.01", "0.1", "0.5", "1.0"], id: \.self) { v in
                        chip(v, active: targetStr == v) { targetStr = v }
                    }
                }

                // Holdings input
                VStack(alignment: .leading, spacing: 8) {
                    lbl("I CURRENTLY HOLD")
                    HStack(spacing: 8) {
                        TextField("0", text: $heldStr)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad).foregroundStyle(.white)
                        Text("BTC").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                if target > 0 {
                    // Progress ring
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 14)
                        Circle().trim(from: 0, to: CGFloat(progress))
                            .stroke(
                                LinearGradient(colors: [.orange, Color(red: 1, green: 0.84, blue: 0)],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.6), value: progress)
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f%%", progress * 100))
                                .font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            Text("of goal").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150).frame(maxWidth: .infinity)

                    // Stats table
                    VStack(spacing: 0) {
                        goalRow("Target", target.btcFormatted, .orange)
                        goalRow("Held", held.btcFormatted, .white)
                        goalRow("Still needed", remaining.btcFormatted, downColor)
                        if let price = currentPrice, remaining > 0 {
                            goalRow("Cost to complete", AppCurrency.current.format(remaining * price), .secondary)
                        }
                        if let price = currentPrice, held > 0 {
                            goalRow("Holdings value", AppCurrency.current.format(held * price), upColor)
                        }
                    }
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if progress >= 1 {
                        Text("Goal reached!")
                            .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.top, 20).padding(.horizontal, 20)
        }
    }

    private func goalRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 16)
        }
    }
}

// MARK: - DCA Share Card

fileprivate struct DCAShareCard: View {
    let amount: Double
    let freqLabel: String
    let btcPer: Double
    let price: Double
    let rows: [(label: String, btc: Double, invested: Double)]

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color(red: 0.15, green: 0.14, blue: 0.13),
                                    Color(red: 0.03, green: 0.02, blue: 0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle()
                .fill(LinearGradient(colors: [.orange, .orange.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3).padding(.vertical, 16)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange).font(.system(size: 13))
                        Text("DCA CALCULATOR").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                    }
                    Spacer()
                    Text("TapBTC").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 10)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(AppCurrency.current.symbol)\(Int(amount))").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text("/ \(freqLabel)").font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(btcPer.btcFormatted).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                        Text("per purchase").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                        HStack {
                            Text(row.label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                .frame(width: 65, alignment: .leading)
                            Spacer()
                            Text(row.btc.btcFormatted).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                            Text("  ·  \(AppCurrency.current.format(row.invested)) in").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 7)
                        if idx < rows.count - 1 {
                            Rectangle().fill(.white.opacity(0.05)).frame(height: 1).padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 4)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)
                appStoreBadgeRow(label: "BTC @ \(BitcoinPrice(usd: price, timestamp: Date()).formatted)")
            }
        }
        .frame(width: 375, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Shared footer

fileprivate func appStoreBadgeRow(label: String) -> some View {
    HStack {
        HStack(spacing: 6) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: -1) {
                Text("Download on the").font(.system(size: 7.5)).foregroundStyle(.white.opacity(0.8))
                Text("App Store").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 9))
        Spacer()
        Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 20).padding(.vertical, 10)
}

#if DEBUG
#Preview { CalculatorsView(currentPrice: 96_420) }
#endif
