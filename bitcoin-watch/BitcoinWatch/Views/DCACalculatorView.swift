import SwiftUI
import LinkPresentation

struct DCACalculatorView: View {
    let currentPrice: Double?

    @State private var amountText = "100"
    @State private var frequency: Frequency = .weekly
    @Environment(\.dismiss) private var dismiss

    enum Frequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var purchasesPerYear: Double {
            switch self {
            case .daily:   return 365
            case .weekly:  return 52
            case .monthly: return 12
            }
        }

        var shortLabel: String {
            switch self {
            case .daily:   return "day"
            case .weekly:  return "week"
            case .monthly: return "month"
            }
        }
    }

    private var amount: Double { Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0 }

    private var btcPerPurchase: Double {
        guard let price = currentPrice, price > 0, amount > 0 else { return 0 }
        return amount / price
    }

    private let projectionYears: [(label: String, years: Double)] = [
        ("1 Year", 1), ("2 Years", 2), ("5 Years", 5), ("10 Years", 10)
    ]

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
                    VStack(spacing: 24) {
                        inputSection
                        if amount > 0, let price = currentPrice, price > 0 {
                            perPurchaseBadge(price: price)
                            projectionSection
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("DCA Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.orange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { shareCard() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(amount <= 0 || currentPrice == nil)
                }
            }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("INVEST PER PERIOD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    TextField("100", text: $amountText)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack(spacing: 8) {
                ForEach(["25", "50", "100", "500"], id: \.self) { val in
                    Button(val) { amountText = val }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(amountText == val ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(amountText == val ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("FREQUENCY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack(spacing: 0) {
                    ForEach(Frequency.allCases, id: \.rawValue) { freq in
                        Button(freq.rawValue) {
                            withAnimation(.easeInOut(duration: 0.15)) { frequency = freq }
                        }
                        .font(.system(size: 14, weight: frequency == freq ? .semibold : .regular))
                        .foregroundStyle(frequency == freq ? .orange : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(frequency == freq ? Color.orange.opacity(0.15) : Color.clear)
                    }
                }
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Per-purchase badge

    private func perPurchaseBadge(price: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("PER PURCHASE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(btcPerPurchase.btcFormatted)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("BTC PRICE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(BitcoinPrice(usd: price, timestamp: Date()).formatted)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Projection table

    private var projectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCUMULATION PROJECTION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(projectionYears.enumerated()), id: \.offset) { idx, row in
                    let btc = btcPerPurchase * frequency.purchasesPerYear * row.years
                    let invested = amount * frequency.purchasesPerYear * row.years

                    HStack {
                        Text(row.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(btc.btcFormatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("$\(Int(invested).formatted()) invested")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(idx % 2 == 0 ? 0.05 : 0.03))

                    if idx < projectionYears.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Share

    @MainActor
    private func shareCard() {
        guard let price = currentPrice else { return }
        let card = DCAShareCardView(
            amount: amount,
            frequency: frequency,
            btcPerPurchase: btcPerPurchase,
            currentPrice: price
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }

        let metadata = LPLinkMetadata()
        metadata.url = URL(string: "https://rjlcevans.com/tapbtc")
        metadata.title = String(format: "I stack $%.0f in Bitcoin every \(frequency.shortLabel) with TapBTC", amount)
        metadata.imageProvider = NSItemProvider(object: image)

        let item = BTCShareItem(metadata: metadata)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController { top = next }
        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        top.present(vc, animated: true)
    }
}

// MARK: - Share Card

struct DCAShareCardView: View {
    let amount: Double
    let frequency: DCACalculatorView.Frequency
    let btcPerPurchase: Double
    let currentPrice: Double

    private let shareRows: [(label: String, years: Double)] = [
        ("1 Year", 1), ("5 Years", 5), ("10 Years", 10)
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.14, blue: 0.13),
                         Color(red: 0.03, green: 0.02, blue: 0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(LinearGradient(colors: [.orange, .orange.opacity(0.3)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
                .padding(.vertical, 16)

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 13))
                        Text("DCA CALCULATOR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    Spacer()
                    Text("TapBTC")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                // Plan summary
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("$\(Int(amount))")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(frequency.shortLabel)")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(btcPerPurchase.btcFormatted)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("per purchase")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                // Projection rows
                VStack(spacing: 0) {
                    ForEach(Array(shareRows.enumerated()), id: \.offset) { idx, row in
                        let btc = btcPerPurchase * frequency.purchasesPerYear * row.years
                        let invested = amount * frequency.purchasesPerYear * row.years
                        HStack {
                            Text(row.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 65, alignment: .leading)
                            Spacer()
                            Text(btc.btcFormatted)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("  ·  $\(Int(invested).formatted()) in")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        if idx < shareRows.count - 1 {
                            Rectangle().fill(.white.opacity(0.05)).frame(height: 1).padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 4)

                Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.horizontal, 20)

                // Footer
                HStack {
                    appStoreBadge
                    Spacer()
                    Text("BTC @ \(BitcoinPrice(usd: currentPrice, timestamp: Date()).formatted)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
        .frame(width: 375, height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var appStoreBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.logo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: -1) {
                Text("Download on the")
                    .font(.system(size: 7.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                Text("App Store")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Helpers

fileprivate extension Double {
    var btcFormatted: String {
        if self >= 1       { return String(format: "%.4f BTC", self) }
        if self >= 0.001   { return String(format: "%.6f BTC", self) }
        return               String(format: "%.8f BTC", self)
    }
}

#if DEBUG
#Preview {
    DCACalculatorView(currentPrice: 96_420)
}
#endif
