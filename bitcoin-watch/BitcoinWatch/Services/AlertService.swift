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
    // The currency `targetPrice` was entered in. Needed because the app only
    // has one *global* display currency — if the user switches currency
    // after creating an alert, `targetPrice` must be converted at compare
    // time or the alert silently goes dead (or fires immediately) against
    // the new currency's much larger/smaller numbers.
    var currency: AppCurrency = .current

    enum Direction: String, Codable {
        case above, below
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, targetPrice, direction, isRepeating, isEnabled, createdAt, lastFiredAt, currency
    }

    init(id: UUID = UUID(), label: String = "", targetPrice: Double, direction: Direction,
         isRepeating: Bool = false, isEnabled: Bool = true, createdAt: Date = Date(),
         lastFiredAt: Date? = nil, currency: AppCurrency = .current) {
        self.id = id
        self.label = label
        self.targetPrice = targetPrice
        self.direction = direction
        self.isRepeating = isRepeating
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.lastFiredAt = lastFiredAt
        self.currency = currency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        targetPrice = try c.decode(Double.self, forKey: .targetPrice)
        direction = try c.decode(Direction.self, forKey: .direction)
        isRepeating = try c.decode(Bool.self, forKey: .isRepeating)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastFiredAt = try c.decodeIfPresent(Date.self, forKey: .lastFiredAt)
        // Pre-fix alerts predate per-alert currency tagging; best-effort
        // default to whatever currency is selected now rather than
        // fabricating a history we don't have.
        currency = try c.decodeIfPresent(AppCurrency.self, forKey: .currency) ?? .current
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
        if alerts[i].isEnabled && alerts[i].lastFiredAt != nil {
            // Re-arm: give the alert a fresh identity so the server forgets the
            // old fired state — otherwise the next sync would disable it again.
            alerts[i].id = UUID()
            alerts[i].lastFiredAt = nil
        }
        save()
    }

    func update(_ alert: PriceAlert) {
        guard let i = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        var updated = alert
        if updated.lastFiredAt != nil {
            // Editing a fired alert re-arms it (fresh identity, see toggle).
            updated.id = UUID()
            updated.lastFiredAt = nil
            updated.isEnabled = true
        }
        alerts[i] = updated
        save()
    }

    /// Merge fired-state reported by the push server so foreground checks and the
    /// alert list stay consistent with pushes sent while the app was closed.
    func applyServerFired(_ fired: [String: Double]) {
        var changed = false
        for (idString, ts) in fired {
            guard let id = UUID(uuidString: idString),
                  let i = alerts.firstIndex(where: { $0.id == id }) else { continue }
            // Adopt the server's fire time if it's newer than ours, so the local
            // cooldown reflects a push that went out while the app was closed and
            // the foreground check doesn't re-fire it. Server timestamps are in
            // milliseconds (JS Date.now()).
            let serverDate = Date(timeIntervalSince1970: ts / 1000)
            if alerts[i].lastFiredAt == nil || serverDate > alerts[i].lastFiredAt! {
                alerts[i].lastFiredAt = serverDate
                changed = true
            }
            if !alerts[i].isRepeating && alerts[i].isEnabled {
                alerts[i].isEnabled = false
                changed = true
            }
        }
        if changed { persist() }  // persist only — avoid a sync loop
    }

    func checkAndFire(currentPrice: Double) {
        var changed = false
        for i in alerts.indices {
            guard alerts[i].isEnabled else { continue }
            // `currentPrice` is in the live display currency; `targetPrice`
            // may have been entered under a different one (if the user
            // switched currency since), so compare in a common currency.
            let target = CurrencyRates.shared.convert(
                alerts[i].targetPrice, from: alerts[i].currency, to: .current)
            let triggered = alerts[i].direction == .above
                ? currentPrice >= target
                : currentPrice <= target
            guard triggered else { continue }

            // 1-hour cooldown keeps repeating alerts from spamming every 15s
            if let last = alerts[i].lastFiredAt, Date().timeIntervalSince(last) < 3600 { continue }

            fireNotification(for: alerts[i], currentPrice: currentPrice, targetPrice: target)
            alerts[i].lastFiredAt = Date()
            if !alerts[i].isRepeating { alerts[i].isEnabled = false }
            changed = true
            // A hit alert while the app is open is a delightful moment.
            if UIApplication.shared.applicationState == .active {
                ReviewManager.shared.markGoodMoment()
            }
        }
        if changed { save() }
    }

    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func fireNotification(for alert: PriceAlert, currentPrice: Double, targetPrice: Double) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let content = UNMutableNotificationContent()
        let dir = alert.direction == .above ? "above" : "below"
        let fmt = BitcoinPrice(usd: currentPrice, timestamp: Date()).formatted
        // Use the already-converted target (in the current display currency),
        // not the raw stored value which may still be tagged to an older currency.
        let tgt = BitcoinPrice(usd: targetPrice, timestamp: Date()).formatted
        content.title = alert.label.isEmpty ? "Bitcoin Price Alert" : alert.label
        content.body  = "BTC is now \(fmt) — \(dir) your target of \(tgt)"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(alerts) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func save() {
        persist()
        // Push the updated alert list to the server so background pushes reflect it.
        Task { await PushService.shared.sync() }
    }

    private func load() {
        // Migrate single legacy alert → new array format, one-time
        if let legacy = legacyAlert() {
            alerts = [legacy]
            persist()
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
