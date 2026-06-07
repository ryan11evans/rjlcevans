import SwiftUI

struct PriceAlertView: View {
    @Environment(\.dismiss) var dismiss
    @State private var targetText: String = ""
    @State private var alertAbove: Bool = true
    @State private var permissionDenied = false
    @Binding var hasActiveAlert: Bool

    private let alert = AlertService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                VStack(spacing: 28) {
                    // Direction picker
                    HStack(spacing: 0) {
                        dirButton(label: "Goes Above", value: true)
                        dirButton(label: "Goes Below", value: false)
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Price input
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        TextField("100,000", text: $targetText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .keyboardType(.numberPad)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                    .padding(.horizontal)

                    if permissionDenied {
                        Text("Enable notifications in Settings → TapBTC to use price alerts.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Active alert info
                    if alert.alertEnabled, let t = alert.targetPrice {
                        let dir = alert.alertAbove ? "above" : "below"
                        let fmt = BitcoinPrice(usd: t, timestamp: Date()).formatted
                        HStack {
                            Image(systemName: "bell.fill").foregroundStyle(.orange)
                            Text("Active: notify when \(dir) \(fmt)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") {
                                alert.alertEnabled = false
                                alert.targetPrice = nil
                                hasActiveAlert = false
                                dismiss()
                            }
                            .font(.footnote)
                            .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        Task { await saveAlert() }
                    } label: {
                        Text("Set Alert")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(RoundedRectangle(cornerRadius: 14).fill(targetPrice == nil ? Color.orange.opacity(0.4) : .orange))
                            .foregroundStyle(.black)
                    }
                    .disabled(targetPrice == nil)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle("Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let existing = alert.targetPrice {
                    targetText = String(Int(existing))
                    alertAbove = alert.alertAbove
                }
            }
        }
    }

    @ViewBuilder
    private func dirButton(label: String, value: Bool) -> some View {
        Button {
            alertAbove = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(alertAbove == value ? Color.orange : Color.clear)
                .foregroundStyle(alertAbove == value ? .black : .secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var targetPrice: Double? {
        Double(targetText.replacingOccurrences(of: ",", with: ""))
    }

    private func saveAlert() async {
        guard let price = targetPrice else { return }
        let granted = await alert.requestPermission()
        guard granted else { permissionDenied = true; return }
        alert.targetPrice = price
        alert.alertAbove = alertAbove
        alert.alertEnabled = true
        hasActiveAlert = true
        dismiss()
    }
}
