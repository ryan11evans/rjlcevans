import SwiftUI
import UIKit
import UserNotifications

@main
struct BitcoinWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

// Receives the APNs device token and forwards it to PushService so the backend
// can send price-alert pushes while the app is closed.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PushService.shared.registerIfAuthorized()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushService.shared.setDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No-op: background pushes simply stay off until registration succeeds.
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
