import Foundation
import StoreKit
import WidgetKit

// TapBTC Pro — one-time unlock via StoreKit 2.
// Free: the price widget, one custom price alert, and holdings inside the app.
// Pro: your stack on the Home Screen widget, Apple Watch, and daily briefing,
// plus unlimited price alerts, volatility alerts, exclusive icons, and widget themes.
enum ProPurchaseResult: Equatable {
    case success
    case cancelled
    case pending
    case unavailable
    case failed(String)
}

enum ProRestoreResult: Equatable {
    case restored
    case nothingToRestore
    case failed(String)
}

@MainActor
final class ProService: ObservableObject {
    static let shared = ProService()

    static let productID = "com.rjlcevans.rjlbtcwatch.pro"
    static let freeAlertLimit = 1

    @Published private(set) var isPro: Bool
    @Published private(set) var product: Product?
    /// True until the first StoreKit product fetch settles.
    @Published private(set) var isLoadingProduct = true
    /// True when the last fetch finished with no product to sell.
    @Published private(set) var productLoadFailed = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // Cached so the unlock works instantly (and offline) after purchase.
        isPro = UserDefaults.shared.bool(forKey: "isProUnlocked")
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    /// StoreKit's localized price, once the product has loaded. Nil until then
    /// so the UI never invents a US "$1.99" for other storefronts.
    var displayPrice: String? { product?.displayPrice }

    func refresh() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            if let found = products.first {
                product = found
                productLoadFailed = false
            } else if product == nil {
                productLoadFailed = true
            }
        } catch {
            if product == nil { productLoadFailed = true }
        }
        await updateEntitlement()
    }

    func purchase() async -> ProPurchaseResult {
        if product == nil { await refresh() }
        guard let product else { return .unavailable }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The App Store couldn't verify this purchase.")
                }
                await transaction.finish()
                setPro(true)
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Something went wrong with the purchase.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> ProRestoreResult {
        do {
            try await AppStore.sync()
        } catch {
            return .failed(error.localizedDescription)
        }
        await updateEntitlement()
        return isPro ? .restored : .nothingToRestore
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
            // Widget can now show holdings; server + Watch need updated Pro state.
            WidgetCenter.shared.reloadAllTimelines()
            ConnectivityManager.shared.syncHoldings()
            Task { await PushService.shared.sync() }
        }
    }
}
