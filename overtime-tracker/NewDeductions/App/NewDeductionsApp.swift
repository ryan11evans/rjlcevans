import SwiftUI

@main
struct NewDeductionsApp: App {
    private let container = AppModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
