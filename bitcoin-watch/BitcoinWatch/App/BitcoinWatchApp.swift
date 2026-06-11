import SwiftUI

@main
struct BitcoinWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var priceService = PriceService.shared

    init() {
        BackgroundRefresh.register()
        BTCShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(priceService)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                priceService.startForegroundRefresh()
            case .background:
                priceService.stopForegroundRefresh()
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
