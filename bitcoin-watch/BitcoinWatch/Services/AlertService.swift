import Foundation
import UserNotifications

class AlertService {
    static let shared = AlertService()

    private let defaults = UserDefaults.shared

    var targetPrice: Double? {
        get { defaults.object(forKey: "alertTargetPrice") as? Double }
        set { defaults.set(newValue, forKey: "alertTargetPrice") }
    }

    var alertAbove: Bool {
        get { defaults.bool(forKey: "alertAbove") }
        set { defaults.set(newValue, forKey: "alertAbove") }
    }

    var alertEnabled: Bool {
        get { defaults.bool(forKey: "alertEnabled") }
        set { defaults.set(newValue, forKey: "alertEnabled") }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func checkAndFire(currentPrice: Double) {
        guard alertEnabled, let target = targetPrice else { return }
        let triggered = alertAbove ? currentPrice >= target : currentPrice <= target
        guard triggered else { return }

        alertEnabled = false

        let content = UNMutableNotificationContent()
        content.title = "Bitcoin Price Alert"
        let dir = alertAbove ? "above" : "below"
        let fmt = BitcoinPrice(usd: currentPrice, timestamp: Date()).formatted
        let tgt = BitcoinPrice(usd: target, timestamp: Date()).formatted
        content.body = "BTC is now \(fmt) — \(dir) your target of \(tgt)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
