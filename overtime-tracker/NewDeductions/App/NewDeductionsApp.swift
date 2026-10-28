import SwiftUI

@main
struct NewDeductionsApp: App {
    @StateObject private var premiumStore = PremiumStore()
    private let container = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(premiumStore)
                .task { await premiumStore.start() }
        }
        .modelContainer(container)
    }
}
