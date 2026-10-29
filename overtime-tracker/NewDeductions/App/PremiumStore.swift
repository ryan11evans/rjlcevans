import StoreKit
import SwiftUI

/// Free: the per-paycheck estimate, a VIN check, and the current week's hours.
/// New Deductions Pro is one non-consumable. No subscription.
@MainActor
final class PremiumStore: ObservableObject {
    static let proID = "com.rjlcevans.newdeductions.pro"
    /// Earlier builds sold these. A verified purchase still unlocks Pro. They are not offered.
    static let legacyIDs: Set<String> = [
        "com.rjlcevans.newdeductions.yearly",
        "com.rjlcevans.newdeductions.lifetime"
    ]
    static let productIDs: Set<String> = legacyIDs.union([proID])

    @Published private(set) var isPremium = false
    @Published private(set) var proProduct: Product?
    @Published var purchaseError: String?

    private var updates: Task<Void, Never>?
    private var started = false

    func start() async {
        if !started {
            started = true
            updates = Task { [weak self] in
                await self?.observeTransactions()
            }
        }
        await refreshEntitlements()
        await loadProProduct()
    }

    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                premium = true
            }
        }
        isPremium = premium
    }

    func loadProProduct() async {
        do {
            let products = try await Product.products(for: [Self.proID])
            proProduct = products.first
        } catch {
            proProduct = nil
        }
    }

    func purchasePro() async {
        if proProduct == nil {
            await loadProProduct()
        }
        guard let proProduct else {
            purchaseError = "New Deductions Pro is not available from the App Store right now."
            return
        }
        do {
            let result = try await proProduct.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    purchaseError = "The App Store could not verify that purchase."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async -> String {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return isPremium ? "Purchases restored." : "No purchase was found for this Apple ID."
        } catch {
            return error.localizedDescription
        }
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            if Task.isCancelled { return }
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }
}
