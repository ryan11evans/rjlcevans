import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premium: PremiumStore

    var body: some View {
        SubscriptionStoreView(productIDs: [PremiumStore.yearlyID]) {
            VStack(alignment: .leading, spacing: 12) {
                StopwatchHero(diameter: 96)
                    .frame(maxWidth: .infinity)
                Text("Full estimate")
                    .font(Theme.rounded(.title, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Free includes a VIN check and the current overtime week. The full estimate adds every workweek, the year dial, the car-loan deduction, code TT, the W-4 helper, and CSV export.")
                    .font(Theme.rounded(.body))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                lifetimeButton
                Text("The yearly plan renews through Apple until you cancel it. The lifetime unlock is a one-time purchase and does not renew.")
                    .font(Theme.rounded(.footnote))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                EstimateFootnote()
                HStack(spacing: 16) {
                    Link("Privacy", destination: LegalURLs.privacy)
                    Link("Terms", destination: LegalURLs.terms)
                    Link("Support", destination: LegalURLs.support)
                }
                .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .storeButton(.visible, for: .restorePurchases)
        .onInAppPurchaseCompletion { _, _ in
            Task { await premium.refreshEntitlements() }
        }
        .onChange(of: premium.isPremium) { _, unlocked in
            if unlocked { dismiss() }
        }
        .overlay(alignment: .topTrailing) {
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
                .padding()
        }
        .alert("Purchase", isPresented: purchaseAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(premium.purchaseError ?? "")
        }
        .task {
            await premium.loadLifetimeProduct()
        }
    }

    @ViewBuilder
    private var lifetimeButton: some View {
        if let product = premium.lifetimeProduct {
            Button {
                Task { await premium.purchaseLifetime() }
            } label: {
                Text("Lifetime unlock \(product.displayPrice)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("One-time purchase. Does not renew.")
        } else {
            Text("Lifetime unlock, \(AppFormatting.currency(Decimal(string: "29.99", locale: Locale(identifier: "en_US_POSIX"))!)), appears here when the App Store product loads. It does not renew.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var purchaseAlertPresented: Binding<Bool> {
        Binding(
            get: { premium.purchaseError != nil },
            set: { if !$0 { premium.purchaseError = nil } }
        )
    }
}

struct PremiumLockedSection: View {
    @EnvironmentObject private var premium: PremiumStore
    let message: String
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Full estimate")
                    .font(Theme.rounded(.headline, weight: .bold))
            } icon: {
                Image(systemName: "lock.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.gold, Theme.emerald)
            }
            Text(message)
                .font(Theme.rounded(.subheadline))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Unlock") { showPaywall = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .sheet(isPresented: $showPaywall) {
            PaywallView().environmentObject(premium)
        }
    }
}
