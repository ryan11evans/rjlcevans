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

        let payload: [String: Any] = ["token": token, "alerts": alerts]
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
