import Foundation
import UserNotifications
import UIKit

struct PriceAlert: Codable, Identifiable {
    var id = UUID()
    var label: String = ""
    var targetPrice: Double
    var direction: Direction
    var isRepeating: Bool = false
    var isEnabled: Bool = true
    var createdAt: Date = Date()
    var lastFiredAt: Date? = nil

    enum Direction: String, Codable {
        case above, below
    }
}

@MainActor
class AlertService: ObservableObject {
    static let shared = AlertService()

    @Published var alerts: [PriceAlert] = []

    var alertEnabled: Bool { alerts.contains { $0.isEnabled } }

    private let defaults = UserDefaults.shared
    private let storageKey = "priceAlerts_v2"

    init() { load() }

    func add(_ alert: PriceAlert) {
        alerts.append(alert)
        save()
    }

    func remove(at offsets: IndexSet) {
        alerts.remove(atOffsets: offsets)
        save()
    }

    func toggle(id: UUID) {
        guard let i = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[i].isEnabled.toggle()
        save()
    }

    func update(_ alert: PriceAlert) {
        guard let i = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[i] = alert
        save()
    }

    func checkAndFire(currentPrice: Double) {
        var changed = false
        for i in alerts.indices {
            guard alerts[i].isEnabled else { continue }
            let triggered = alerts[i].direction == .above
                ? currentPrice >= alerts[i].targetPrice
                : currentPrice <= alerts[i].targetPrice
            guard triggered else { continue }

            // 1-hour cooldown keeps repeating alerts from spamming every 15s
            if let last = alerts[i].lastFiredAt, Date().timeIntervalSince(last) < 3600 { continue }

            fireNotification(for: alerts[i], currentPrice: currentPrice)
            alerts[i].lastFiredAt = Date()
            if !alerts[i].isRepeating { alerts[i].isEnabled = false }
            changed = true
        }
        if changed { save() }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func fireNotification(for alert: PriceAlert, currentPrice: Double) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let content = UNMutableNotificationContent()
        let dir = alert.direction == .above ? "above" : "below"
        let fmt = BitcoinPrice(usd: currentPrice, timestamp: Date()).formatted
        let tgt = BitcoinPrice(usd: alert.targetPrice, timestamp: Date()).formatted
        content.title = alert.label.isEmpty ? "Bitcoin Price Alert" : alert.label
        content.body  = "BTC is now \(fmt) — \(dir) your target of \(tgt)"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(alerts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        // Migrate single legacy alert → new array format, one-time
        if let legacy = legacyAlert() {
            alerts = [legacy]
            save()
            clearLegacy()
            return
        }
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([PriceAlert].self, from: data) else { return }
        alerts = saved
    }

    private func legacyAlert() -> PriceAlert? {
        guard defaults.bool(forKey: "alertEnabled"),
              let target = defaults.object(forKey: "alertTargetPrice") as? Double else { return nil }
        let dir: PriceAlert.Direction = defaults.bool(forKey: "alertAbove") ? .above : .below
        return PriceAlert(targetPrice: target, direction: dir)
    }

    private func clearLegacy() {
        ["alertEnabled", "alertTargetPrice", "alertAbove"].forEach { defaults.removeObject(forKey: $0) }
    }
}
