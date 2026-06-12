import SwiftUI
import UserNotifications

@main
struct BitcoinWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var priceService = PriceService.shared

    init() {
        BackgroundRefresh.register()
        BTCShortcutsProvider.updateAppShortcutParameters()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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

// Shows notification banners even when the app is in the foreground
private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
}
