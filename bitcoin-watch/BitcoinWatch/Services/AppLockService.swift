import Foundation
import LocalAuthentication

// Optional Face ID / Touch ID / passcode gate. Because the app now shows the
// user's holdings and P&L, this keeps them private on a shared or lost phone.
@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    @Published var isLocked: Bool
    @Published var authError: String?

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
            // Biometrics/passcode became unavailable (e.g. the device
            // passcode was removed after this lock was turned on). Stay
            // locked rather than granting access with zero auth — surface
            // why so the UI can explain it instead of silently failing open.
            authError = error?.localizedDescription ?? "Face ID, Touch ID, or a passcode is required to unlock."
            return
        }
        authError = nil
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "Unlock TapBTC to view your Bitcoin") { success, evalError in
            Task { @MainActor in
                if success {
                    self.isLocked = false
                    self.authError = nil
                } else if let laError = evalError as? LAError,
                          [.userCancel, .systemCancel, .appCancel].contains(laError.code) {
                    // User dismissed the sheet themselves — not a failure worth surfacing.
                    self.authError = nil
                } else if let evalError {
                    self.authError = evalError.localizedDescription
                }
            }
        }
    }
}
