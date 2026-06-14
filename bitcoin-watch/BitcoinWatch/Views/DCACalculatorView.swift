import SwiftUI
import LinkPresentation

// MARK: - Container shell

struct CalculatorsView: View {
    let currentPrice: Double?
    @State private var tab = 0
    @Environment(\.dismiss) private var dismiss

    private let titles = ["DCA Calculator", "What If?", "Goal Tracker"]

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
                        Text("What If").tag(1)
                        Text("Goal").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    TabView(selection: $tab) {
                        DCATab(currentPrice: currentPrice).tag(0)
                        WhatIfTab(currentPrice: currentPrice).tag(1)
                        GoalTab(currentPrice: currentPrice).tag(2)
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
                        Text("$").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.orange)
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
                                        Text("$\(Int(inv).formatted()) in")
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
        meta.title = String(format: "I stack $%.0f in Bitcoin every \(freq.perLabel) with TapBTC", amount)
        meta.imageProvider = NSItemProvider(object: img)
        presentShare(BTCShareItem(metadata: meta))
    }
}

// MARK: - What If Tab

private struct WhatIfTab: View {
    let currentPrice: Double?
    @State private var amountText = "1000"
    @State private var period: Period = .oneYear
    @State private var result: WIResult? = nil
    @State private var loading = false
    @State private var errMsg: String? = nil

    enum Period: String, CaseIterable {
        case oneMonth = "1M", threeMonths = "3M", sixMonths = "6M"
        case oneYear = "1Y", twoYears = "2Y", fiveYears = "5Y"
        var days: Int { switch self { case .oneMonth: 30; case .threeMonths: 90; case .sixMonths: 180; case .oneYear: 365; case .twoYears: 730; case .fiveYears: 1825 } }
        var longLabel: String { switch self { case .oneMonth: "1 month"; case .threeMonths: "3 months"; case .sixMonths: "6 months"; case .oneYear: "1 year"; case .twoYears: "2 years"; case .fiveYears: "5 years" } }
    }

    struct WIResult {
        let invested, histPrice, nowPrice: Double
        let period: Period
        var btc: Double   { invested / histPrice }
        var value: Double { btc * nowPrice }
        var gain: Double  { value - invested }
        var gainPct: Double { gain / invested * 100 }
    }

    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }
    private let upColor   = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Amount
                VStack(alignment: .leading, spacing: 8) {
                    lbl("IF I HAD INVESTED")
                    HStack(spacing: 8) {
                        Text("$").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                        TextField("1000", text: $amountText)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad).foregroundStyle(.white)
                            .onChange(of: amountText) { _, _ in result = nil }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 8) {
                    ForEach(["100", "500", "1000", "5000"], id: \.self) { v in
                        chip(v, active: amountText == v) { amountText = v; result = nil }
                    }
                }

                // Period picker
                VStack(alignment: .leading, spacing: 8) {
                    lbl("HOW LONG AGO")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(Period.allCases, id: \.rawValue) { p in
                            Button(p.rawValue) { withAnimation(.easeInOut(duration: 0.15)) { period = p; result = nil } }
                                .font(.system(size: 15, weight: period == p ? .semibold : .regular))
                                .foregroundStyle(period == p ? .orange : .secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(period == p ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
                                )
                        }
                    }
                }

                Button { Task { await fetch() } } label: {
                    Label(loading ? "Fetching..." : "Calculate", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(amount > 0 && !loading ? Color.orange : Color.gray,
                                    in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(amount <= 0 || loading)

                if loading { ProgressView().tint(.orange).padding() }
                if let e = errMsg { Text(e).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                if let r = result { resultView(r) }

                Spacer(minLength: 40)
            }
            .padding(.top, 20).padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func resultView(_ r: WIResult) -> some View {
        let isGain = r.gain >= 0
        let color = isGain ? upColor : downColor

        VStack(spacing: 12) {
            // Headline card
            VStack(spacing: 6) {
                Text("$\(Int(r.invested).formatted()) → $\(Int(r.value).formatted())")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: isGain ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%+.1f%% · %@$%@",
                                r.gainPct, isGain ? "+" : "",
                                abs(Int(r.gain)).formatted()))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(color)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity).padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            // Detail table
            VStack(spacing: 0) {
                wiRow("Invested", "$\(Int(r.invested).formatted())", .secondary)
                wiRow("BTC price \(r.period.longLabel) ago", BitcoinPrice(usd: r.histPrice, timestamp: Date()).formatted, .secondary)
                wiRow("BTC acquired", r.btc.btcFormatted, .orange)
                wiRow("Value today", "$\(Int(r.value).formatted())", color)
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button { doShare(r) } label: {
                Label("Share Result", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func wiRow(_ lbl: String, _ val: String, _ c: Color) -> some View {
        HStack {
            Text(lbl).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Text(val).font(.system(size: 13, weight: .semibold)).foregroundStyle(c)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 16)
        }
    }

    private func fetch() async {
        guard let now = currentPrice, amount > 0 else { return }
        loading = true; errMsg = nil; result = nil
        let date = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? Date()
        let df = DateFormatter(); df.dateFormat = "dd-MM-yyyy"
        let urlStr = "https://api.coingecko.com/api/v3/coins/bitcoin/history?date=\(df.string(from: date))&localization=false"
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url) else {
            errMsg = "Couldn't fetch historical price. Try again."
            loading = false; return
        }
        struct R: Decodable {
            struct MD: Decodable { struct P: Decodable { let usd: Double }; let current_price: P }
            let market_data: MD?
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let hist = r.market_data?.current_price.usd else {
            errMsg = "No price data available for that period."
            loading = false; return
        }
        result = WIResult(invested: amount, histPrice: hist, nowPrice: now, period: period)
        loading = false
    }

    @MainActor private func doShare(_ r: WIResult) {
        let card = WhatIfShareCard(result: r).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card); renderer.scale = 3
        guard let img = renderer.uiImage else { return }
        let meta = LPLinkMetadata()
        meta.url = URL(string: "https://rjlcevans.com/tapbtc")
        meta.title = String(format: "$%.0f invested %@ ago is worth $%.0f today — TapBTC",
                            r.invested, r.period.longLabel, r.value)
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
                            goalRow("Cost to complete", "$\(Int(remaining * price).formatted())", .secondary)
                        }
                        if let price = currentPrice, held > 0 {
                            goalRow("Holdings value", "$\(Int(held * price).formatted())", upColor)
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
                    Text("$\(Int(amount))").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.white)
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
                            Text("  ·  $\(Int(row.invested).formatted()) in").font(.system(size: 11)).foregroundStyle(.secondary)
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

// MARK: - What If Share Card

fileprivate struct WhatIfShareCard: View {
    let result: WhatIfTab.WIResult

    private let upColor   = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let downColor = Color(red: 1, green: 0.27, blue: 0.23)
    private var isGain: Bool { result.gain >= 0 }
    private var color: Color { isGain ? upColor : downColor }

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color(red: 0.15, green: 0.14, blue: 0.13),
                                    Color(red: 0.03, green: 0.02, blue: 0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Rectangle()
                .fill(LinearGradient(colors: [color, color.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3).padding(.vertical, 16)

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(.orange).font(.system(size: 13))
                        Text("WHAT IF?").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                    }
                    Spacer()
                    Text("TapBTC").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 10)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("If I bought \(result.period.longLabel) ago")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Text("$\(Int(result.invested).formatted()) → $\(Int(result.value).formatted())")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: isGain ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%+.1f%%  ·  %@$%@",
                                    result.gainPct, isGain ? "+" : "",
                                    abs(Int(result.gain)).formatted()))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                }
                .padding(.horizontal, 20).padding(.vertical, 14)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("THEN").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                        Text(BitcoinPrice(usd: result.histPrice, timestamp: Date()).formatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.system(size: 12))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("NOW").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
                        Text(BitcoinPrice(usd: result.nowPrice, timestamp: Date()).formatted)
                            .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(color)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 10)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)
                appStoreBadgeRow(label: result.btc.btcFormatted + " BTC")
            }
        }
        .frame(width: 375, height: 270)
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
