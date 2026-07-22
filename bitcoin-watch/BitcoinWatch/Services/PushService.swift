import Foundation
import UIKit
import UserNotifications

// Talks to the TapBTC push backend (a Cloudflare Worker) so that price alerts
// fire even when the app is closed. Uploads this device's APNs token + current
// alerts; the server does the actual price monitoring and sends the pushes.
@MainActor
final class PushService: ObservableObject {
    static let shared = PushService()

    // ⚠️ Set this to your deployed Worker URL (see push-server/README.md).
    // Until it's set, background alerts won't work but the app is otherwise fine.
    private let serverURL = URL(string: "https://tapbtc-push.ryan11evans.workers.dev")!

    private let tokenKey = "apnsDeviceToken"

    private var deviceToken: String? {
        get { UserDefaults.shared.string(forKey: tokenKey) }
        set { UserDefaults.shared.set(newValue, forKey: tokenKey) }
    }

    /// Request notification permission and register for remote (server) pushes.
    /// Returns whether permission was granted.
    func enable() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    /// If the user already granted notifications, refresh the APNs token on launch.
    func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Called by the AppDelegate when APNs hands us a device token.
    func setDeviceToken(_ data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await sync() }
    }

    /// Upload the current token + alert list to the push server.
    func sync() async {
        guard let token = deviceToken else { return }

        let alerts = AlertService.shared.alerts.map { a -> [String: Any] in
            [
                "id": a.id.uuidString,
                "targetPrice": a.targetPrice,
                "direction": a.direction.rawValue,
                "label": a.label,
                "repeating": a.isRepeating,
                "enabled": a.isEnabled,
            ]
        }

        let defaults = UserDefaults.shared
        let isPro = defaults.bool(forKey: "isProUnlocked")

        var payload: [String: Any] = [
            "token": token,
            "alerts": alerts,
            "athAlert": defaults.object(forKey: "athAlertEnabled") as? Bool ?? true,
            "milestoneAlert": defaults.object(forKey: "milestoneAlertEnabled") as? Bool ?? true,
        ]
        // Teach the server the real ATH so its new-high detection is accurate.
        if let ath = StatsService.shared.stats?.ath {
            payload["knownATH"] = ath
        }

        // Pro-only server features. Only mark enabled when the user is Pro so
        // the server never fires them for a free device.
        let volEnabled = isPro && defaults.bool(forKey: "volatilityAlertEnabled")
        let threshold = defaults.object(forKey: "volatilityThreshold") as? Double ?? 5
        payload["volatility"] = ["enabled": volEnabled, "threshold": threshold]

        let briefEnabled = isPro && defaults.bool(forKey: "dailyBriefingEnabled")
        let hour = defaults.object(forKey: "dailyBriefingHour") as? Int ?? 8
        let tz = TimeZone.current.secondsFromGMT() / 60
        payload["briefing"] = ["enabled": briefEnabled, "hour": hour, "tz": tz]

        // Only share holdings when the daily briefing needs it (privacy).
        if briefEnabled {
            payload["holdings"] = HoldingsService.shared.amount
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var req = URLRequest(url: serverURL.appendingPathComponent("register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }

        // Server echoes which alerts have already fired so we don't double-fire
        // them in the foreground.
        struct Resp: Decodable { let fired: [String: Double] }
        if let resp = try? JSONDecoder().decode(Resp.self, from: data) {
            AlertService.shared.applyServerFired(resp.fired)
        }
    }
}
