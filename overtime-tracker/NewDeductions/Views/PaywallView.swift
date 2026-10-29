import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premium: PremiumStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Deductions Pro")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                        Text("One-time $14.99. No subscription.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.gold)
                        Text("Put the overtime estimate on your W-4, and check that W-2 code TT matches your log. Estimates only, not tax advice.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.heroGradient))

                    SoftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Free")
                                .font(.headline)
                            Text("The per-paycheck boost, a VIN check, and the current week’s hours.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SoftCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pro")
                                .font(.headline)
                                .foregroundStyle(Theme.emerald)
                            Text("W-4 helper, W-2 Code TT check, hours history beyond the current week, the car-loan deduction, and Summary with CSV export.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await premium.purchasePro() }
                    } label: {
                        Text(purchaseTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("One-time purchase. No subscription.")

                    Button("Restore Purchases") {
                        Task { restoreMessage = await premium.restore() }
                    }
                    .frame(maxWidth: .infinity)

                    Text(AppCopy.estimateFootnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Link("Privacy", destination: LegalURLs.privacy)
                        Link("Terms", destination: LegalURLs.terms)
                        Link("Support", destination: LegalURLs.support)
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: premium.isPremium) { _, unlocked in
            if unlocked { dismiss() }
        }
        .alert("Purchase", isPresented: purchaseAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(premium.purchaseError ?? "")
        }
        .alert("Restore Purchases", isPresented: restoreAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .task {
            await premium.loadProProduct()
        }
    }

    @State private var restoreMessage: String?

    private var purchaseTitle: String {
        if let price = premium.proProduct?.displayPrice {
            return "Unlock Pro \(price)"
        }
        return "Unlock Pro $14.99"
    }

    private var purchaseAlertPresented: Binding<Bool> {
        Binding(
            get: { premium.purchaseError != nil },
            set: { if !$0 { premium.purchaseError = nil } }
        )
    }

    private var restoreAlertPresented: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })
    }
}

struct PremiumLockedSection: View {
    @EnvironmentObject private var premium: PremiumStore
    let message: String
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pro", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(Theme.emerald)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Unlock Pro") { showPaywall = true }
                .buttonStyle(.borderedProminent)
            Text("One-time $14.99. No subscription.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(premium)
        }
    }
}
