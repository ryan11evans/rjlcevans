import StoreKit
import SwiftUI

/// Free tier: a VIN check and the current overtime workweek.
/// Yearly subscription or the lifetime non-consumable unlocks everything else.
@MainActor
final class PremiumStore: ObservableObject {
    static let yearlyID = "com.rjlcevans.newdeductions.yearly"
    static let lifetimeID = "com.rjlcevans.newdeductions.lifetime"
    static let productIDs: Set<String> = [yearlyID, lifetimeID]

    @Published private(set) var isPremium = false
    @Published private(set) var lifetimeProduct: Product?
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
        await loadLifetimeProduct()
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

    func loadLifetimeProduct() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeID])
            lifetimeProduct = products.first
        } catch {
            lifetimeProduct = nil
        }
    }

    func purchaseLifetime() async {
        if lifetimeProduct == nil {
            await loadLifetimeProduct()
        }
        guard let lifetimeProduct else {
            purchaseError = "The lifetime unlock is not available from the App Store right now."
            return
        }
        do {
            let result = try await lifetimeProduct.purchase()
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
            return isPremium ? "Purchases restored." : "No active purchase was found for this Apple ID."
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
