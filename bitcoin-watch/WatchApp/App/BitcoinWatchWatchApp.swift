import SwiftUI
import WatchKit

@main
struct BitcoinWatchWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(WatchPriceService.shared)
        }
    }
}

class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchConnectivityReceiver.shared.activate()
    }
}
