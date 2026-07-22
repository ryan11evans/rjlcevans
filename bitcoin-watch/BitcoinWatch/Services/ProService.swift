import Foundation
import StoreKit
import WidgetKit

// TapBTC Pro — one-time unlock via StoreKit 2.
// Free tier: up to `freeAlertLimit` custom price alerts.
// Pro: unlimited alerts (+ future Pro features).
@MainActor
final class ProService: ObservableObject {
    static let shared = ProService()

    static let productID = "com.rjlcevans.rjlbtcwatch.pro"
    static let freeAlertLimit = 2

    @Published private(set) var isPro: Bool
    @Published private(set) var product: Product?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Cached so the unlock works instantly (and offline) after purchase.
        isPro = UserDefaults.shared.bool(forKey: "isProUnlocked")
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    var priceText: String { product?.displayPrice ?? "$1.99" }

    func refresh() async {
        product = try? await Product.products(for: [Self.productID]).first
        await updateEntitlement()
    }

    /// Returns true if the purchase completed.
    @discardableResult
    func purchase() async -> Bool {
        var product = self.product
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        guard let product else { return false }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            setPro(true)
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await updateEntitlement()
    }

    private func updateEntitlement() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement, t.productID == Self.productID, t.revocationDate == nil {
                setPro(true)
                return
            }
        }
        // Deliberately never flips back to false here: a transient StoreKit
        // outage shouldn't lock a paying user out.
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let t) = update, t.productID == Self.productID {
                await t.finish()
                if t.revocationDate == nil { setPro(true) }
            }
        }
    }

    private func setPro(_ value: Bool) {
        let wasChanged = isPro != value
        isPro = value
        UserDefaults.shared.set(value, forKey: "isProUnlocked")
        if wasChanged {
            // Widget can now show holdings; server needs updated Pro prefs.
            WidgetCenter.shared.reloadAllTimelines()
            Task { await PushService.shared.sync() }
        }
    }
}
