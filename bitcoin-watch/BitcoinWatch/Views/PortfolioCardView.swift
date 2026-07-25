import SwiftUI

private let upColor = Color(red: 0.19, green: 0.82, blue: 0.35)
private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

// Main-screen portfolio card. Free users can enter holdings + cost basis and see
// their live value and P&L here; Pro unlocks the same on the widget, Watch, and
// in the daily briefing.
struct PortfolioCardView: View {
    let currentPrice: Double?
    let change24h: Double?
    @ObservedObject private var holdings = HoldingsService.shared
    @State private var showEntry = false

    private var value: Double? {
        guard let price = currentPrice, holdings.hasHoldings else { return nil }
        return holdings.value(at: price)
    }

    var body: some View {
        Button { showEntry = true } label: {
            if holdings.hasHoldings { filledCard } else { emptyCard }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEntry) {
            HoldingsEntryView(currentPrice: currentPrice)
        }
    }

    private var filledCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.orange.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR HOLDINGS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(holdings.formattedAmount)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.map { AppCurrency.current.format($0) } ?? "—")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                trailingSubline
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .glassCard(cornerRadius: 14, shadow: false)
    }

    // Prefer all-time P&L (if cost basis is set); otherwise today's $ move.
    @ViewBuilder private var trailingSubline: some View {
        if let price = currentPrice, let gain = holdings.gain(at: price) {
            let up = gain.amount >= 0
            Text("\(up ? "+" : "-")\(AppCurrency.current.format(abs(gain.amount))) · \(up ? "+" : "")\(String(format: "%.1f", gain.pct * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(up ? upColor : downColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else if let change = change24h, let value {
            let delta = value * change / 100
            Text("\(change >= 0 ? "+" : "-")\(AppCurrency.current.format(abs(delta))) today")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(change >= 0 ? upColor : downColor)
        }
    }

    private var emptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Track your Bitcoin")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Add your holdings to see live value & profit")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.orange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.18), lineWidth: 1))
        )
    }
}

// MARK: - Entry / transaction editor

private enum TransactionMode: String, CaseIterable {
    case buy = "Buy"
    case sell = "Sell"
}

struct HoldingsEntryView: View {
    let currentPrice: Double?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var holdings = HoldingsService.shared
    @ObservedObject private var pro = ProService.shared

    @State private var mode: TransactionMode = .buy
    @State private var amountText = ""
    @State private var priceText = ""
    @State private var showPaywall = false
    @FocusState private var amountFocused: Bool

    private let cur = AppCurrency.current

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if holdings.hasHoldings || holdings.hasSales { summary }
                        addForm
                        if !holdings.purchases.isEmpty { lotList }
                        if !holdings.sales.isEmpty { salesList }
                        if !pro.isPro { proUpsell }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Your Holdings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { amountFocused = true }
        }
        .preferredColorScheme(.dark)
    }

    // Live summary: value, avg cost, P&L
    private var summary: some View {
        VStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("PORTFOLIO VALUE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary).tracking(0.5)
                Text(currentPrice.map { cur.format(holdings.value(at: $0)) } ?? "—")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text(holdings.formattedAmount)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let price = currentPrice, let gain = holdings.gain(at: price) {
                let up = gain.amount >= 0
                HStack(spacing: 16) {
                    metric("AVG COST", holdings.avgCost.map { cur.format($0) } ?? "—", .white)
                    Divider().frame(height: 28).overlay(.white.opacity(0.1))
                    metric("PROFIT / LOSS",
                           "\(up ? "+" : "-")\(cur.format(abs(gain.amount)))",
                           up ? upColor : downColor)
                    Divider().frame(height: 28).overlay(.white.opacity(0.1))
                    metric("RETURN",
                           "\(up ? "+" : "")\(String(format: "%.1f", gain.pct * 100))%",
                           up ? upColor : downColor)
                }
                .frame(maxWidth: .infinity)
            }

            if holdings.hasSales {
                let up = holdings.realizedGain >= 0
                HStack(spacing: 16) {
                    metric("REALIZED P&L",
                           "\(up ? "+" : "-")\(cur.format(abs(holdings.realizedGain)))",
                           up ? upColor : downColor)
                    if let pct = holdings.realizedPct {
                        Divider().frame(height: 28).overlay(.white.opacity(0.1))
                        metric("REALIZED RETURN",
                               "\(pct >= 0 ? "+" : "")\(String(format: "%.1f", pct * 100))%",
                               pct >= 0 ? upColor : downColor)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 18)
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary).tracking(0.3)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
        }
    }

    // Add-a-purchase or log-a-sale form
    private var addForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $mode) {
                ForEach(TransactionMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                field(placeholder: "Amount", text: $amountText, suffix: "BTC")
                    .focused($amountFocused)
                field(placeholder: mode == .buy ? "Buy price" : "Sell price", text: $priceText, suffix: cur.code)
            }

            Text(mode == .buy
                 ? "Leave buy price blank if you just want to track value."
                 : "Sell price is needed to calculate realized profit/loss.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Button {
                guard let amt = Double(amountText), amt > 0 else { return }
                switch mode {
                case .buy:
                    holdings.add(Purchase(amount: amt, price: Double(priceText) ?? 0))
                case .sell:
                    guard let price = Double(priceText), price > 0 else { return }
                    holdings.addSale(Sale(amount: amt, price: price))
                }
                amountText = ""; priceText = ""
                amountFocused = true
            } label: {
                Text(mode == .buy ? "Add" : "Log Sale")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(canSubmit ? Color.orange : Color.orange.opacity(0.4)))
                    .foregroundStyle(.black)
            }
            .disabled(!canSubmit)
        }
    }

    private var canSubmit: Bool {
        guard let amt = Double(amountText), amt > 0 else { return false }
        switch mode {
        case .buy:
            return true
        case .sell:
            guard let price = Double(priceText), price > 0 else { return false }
            return amt <= holdings.totalAmount
        }
    }

    private func field(placeholder: String, text: Binding<String>, suffix: String) -> some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(suffix)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
    }

    private var lotList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR PURCHASES")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary).tracking(0.5)

            VStack(spacing: 0) {
                ForEach(holdings.purchases) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SatsDisplay.formatAmount(p.amount))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(p.price > 0 ? "@ \(cur.format(p.price))" : "no cost basis")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            holdings.remove(p)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    if p.id != holdings.purchases.last?.id {
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 14)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
        }
    }

    private var salesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR SALES")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary).tracking(0.5)

            VStack(spacing: 0) {
                ForEach(holdings.sales) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SatsDisplay.formatAmount(s.amount))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("@ \(cur.format(s.price))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            holdings.removeSale(s)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    if s.id != holdings.sales.last?.id {
                        Divider().overlay(.white.opacity(0.06)).padding(.leading, 14)
                    }
                }
            }
            .glassCard(cornerRadius: 14)
        }
    }

    private var proUpsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep it on your Home Screen")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Pro shows your value & profit on the widget, Watch & a daily briefing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
