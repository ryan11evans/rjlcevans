import SwiftUI

struct SatoshiConverterView: View {
    let btcPrice: Double

    @State private var usdText = ""
    @State private var satText = ""
    @FocusState private var focus: Field?

    private enum Field { case usd, sat }
    private let satsPerBTC: Double = 100_000_000
    private var cur: AppCurrency { AppCurrency.current }

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
                    VStack(spacing: 16) {
                        // ── USD field ─────────────────────────────
                        inputField(
                            label: cur.displayName,
                            prefix: cur.symbol,
                            placeholder: "0.00",
                            text: $usdText,
                            field: .usd
                        )

                        // ── Swap indicator ────────────────────────
                        HStack {
                            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("1 BTC = 100,000,000 sats")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                        }

                        // ── Sats field ────────────────────────────
                        inputField(
                            label: "Satoshis",
                            prefix: "sat",
                            placeholder: "0",
                            text: $satText,
                            field: .sat
                        )
                    }
                    .padding(24)

                    // ── Quick amounts ─────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick amounts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach([1, 10, 50, 100, 500, 1_000, 10_000], id: \.self) { amount in
                                    Button {
                                        usdText = "\(amount)"
                                        focus = nil
                                        recalcFromUSD(usdText)
                                    } label: {
                                        Text("\(cur.symbol)\(amount)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.white.opacity(0.09))
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 4)

                    // ── Context footer ────────────────────────────
                    VStack(spacing: 6) {
                        Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bitcoin price")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(cur.format(btcPrice))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("1 sat equals")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(oneSatFormatted())
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Satoshi Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func inputField(label: String, prefix: String, placeholder: String,
                            text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 10) {
                Text(prefix)
                    .font(.system(size: field == .usd ? 20 : 15,
                                  weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .frame(minWidth: 28, alignment: .leading)

                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($focus, equals: field)
                    .onChange(of: text.wrappedValue) { _, val in
                        guard focus == field else { return }
                        if field == .usd { recalcFromUSD(val) }
                        else             { recalcFromSat(val) }
                    }

                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                        if field == .usd { satText = "" } else { usdText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                focus == field ? Color.orange.opacity(0.5) : Color.white.opacity(0.09),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: focus)
        }
    }

    private func recalcFromUSD(_ raw: String) {
        let clean = raw.filter { $0.isNumber || $0 == "." }
        guard let usd = Double(clean), btcPrice > 0 else { satText = ""; return }
        let sats = (usd / btcPrice) * satsPerBTC
        satText = satFormatter.string(from: NSNumber(value: sats)) ?? "\(Int(sats))"
    }

    private func recalcFromSat(_ raw: String) {
        let clean = raw.filter { $0.isNumber }
        guard let sats = Double(clean), btcPrice > 0 else { usdText = ""; return }
        let usd = (sats / satsPerBTC) * btcPrice
        usdText = String(format: usd < 0.01 ? "%.6f" : "%.2f", usd)
    }

    private func oneSatFormatted() -> String {
        let v = btcPrice / satsPerBTC
        return "\(cur.symbol)\(String(format: "%.6f", v))"
    }

    private var satFormatter: NumberFormatter {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f
    }
}

#if DEBUG
#Preview {
    SatoshiConverterView(btcPrice: 107_324)
}
#endif
