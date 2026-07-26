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
            List {
                Section {
                    inputRow(prefix: cur.symbol, placeholder: "0.00", text: $usdText, field: .usd)
                } header: {
                    Text(cur.displayName)
                } footer: {
                    Text("1 BTC = 100,000,000 sats")
                }

                Section("Satoshis") {
                    inputRow(prefix: "sat", placeholder: "0", text: $satText, field: .sat)
                }

                Section("Quick Amounts") {
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
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bitcoin price")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(cur.format(btcPrice))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                    .listRowBackground(Color.listRowTint)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .nativeListBackground()
            .navigationTitle("Satoshi Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func inputRow(prefix: String, placeholder: String,
                          text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 10) {
            Text(prefix)
                .font(.system(size: field == .usd ? 20 : 15,
                              weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
                .frame(minWidth: 28, alignment: .leading)

            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .bold, design: .rounded))
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
        .listRowBackground(Color.listRowTint)
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
