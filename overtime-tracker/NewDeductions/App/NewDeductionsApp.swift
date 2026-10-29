import SwiftData
import SwiftUI

@main
struct NewDeductionsApp: App {
    @StateObject private var premiumStore: PremiumStore
    private let container: ModelContainer

    init() {
        Theme.applyAppearance()
        _premiumStore = StateObject(wrappedValue: PremiumStore())
        container = AppModelContainer.make()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(premiumStore)
                .tint(Theme.emerald)
                .fontDesign(.rounded)
                .task { await premiumStore.start() }
        }
        .modelContainer(container)
    }
}
