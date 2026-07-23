import Foundation
import LocalAuthentication

// Optional Face ID / Touch ID / passcode gate. Because the app now shows the
// user's holdings and P&L, this keeps them private on a shared or lost phone.
@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    @Published var isLocked: Bool

    var enabled: Bool { UserDefaults.shared.bool(forKey: "requireFaceID") }

    init() {
        // Start locked on cold launch if the setting is on.
        isLocked = UserDefaults.shared.bool(forKey: "requireFaceID")
    }

    /// Biometry/passcode availability — used to gate the Settings toggle.
    static var biometricsAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Lock when the app leaves the foreground (also hides holdings in the switcher).
    func lockIfNeeded() {
        if enabled { isLocked = true }
    }

    /// Lock immediately when the user turns the setting on.
    func lockNow() { isLocked = true }

    func authenticate() {
        guard isLocked else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode set up — don't trap the user out.
            isLocked = false
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock TapBTC to view your Bitcoin") { success, _ in
            Task { @MainActor in
                if success { self.isLocked = false }
            }
        }
    }
}
