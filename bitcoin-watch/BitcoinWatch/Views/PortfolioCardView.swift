import SwiftUI

// Main-screen portfolio card. Free users can enter holdings and see their live
// value here (the "taste"); Pro unlocks the same value on the widget, Watch,
// and in the daily briefing.
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
            if holdings.hasHoldings {
                filledCard
            } else {
                emptyCard
            }
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
                Text("\(holdings.formattedAmount) BTC")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value.map { "$\(Int($0).formatted())" } ?? "—")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let change = change24h, let value {
                    let delta = value * change / 100
                    Text("\(change >= 0 ? "+" : "-")$\(Int(abs(delta)).formatted()) today")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(change >= 0
                            ? Color(red: 0.19, green: 0.82, blue: 0.35)
                            : Color(red: 1, green: 0.27, blue: 0.23))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        )
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
                Text("Add your holdings to see live value")
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

// MARK: - Entry sheet

struct HoldingsEntryView: View {
    let currentPrice: Double?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var holdings = HoldingsService.shared
    @ObservedObject private var pro = ProService.shared
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var showPaywall = false

    private var entered: Double? { Double(text) }
    private var previewValue: Double? {
        guard let price = currentPrice, let amt = entered else { return nil }
        return amt * price
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        // Amount field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOW MUCH BTC DO YOU OWN?")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                            HStack(spacing: 8) {
                                TextField("0.0", text: $text)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .focused($focused)
                                    .foregroundStyle(.white)
                                Text("BTC")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                        }

                        // Live value preview
                        if let v = previewValue {
                            VStack(spacing: 4) {
                                Text("CURRENT VALUE")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .tracking(0.5)
                                Text("$\(Int(v).formatted())")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.orange.opacity(0.08)))
                        }

                        // Pro upsell — the "keep it everywhere" hook
                        if !pro.isPro {
                            Button { showPaywall = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Keep it on your Home Screen")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("Pro shows your value on the widget, Watch & a daily briefing")
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

                        // Save
                        Button {
                            holdings.setAmount(entered ?? 0)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                                .foregroundStyle(.black)
                        }

                        if holdings.hasHoldings {
                            Button("Clear holdings", role: .destructive) {
                                holdings.setAmount(0)
                                dismiss()
                            }
                            .font(.footnote)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Your Holdings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear {
                if holdings.hasHoldings { text = holdings.formattedAmount }
                focused = true
            }
        }
        .preferredColorScheme(.dark)
    }
}
