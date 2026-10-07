import UIKit

/// The iPhone Duo (and similar dual-independent-display devices) has no hinge
/// sensor — folding/unfolding is modeled as the app's single scene getting
/// re-homed between two always-powered-on physical displays (confirmed via
/// each device type's `capabilities.plist`, which declares two `displays[]`
/// entries and no hinge capability). The OS fires `UIScreen.didConnect` /
/// `UIScene.didActivate` correctly when that happens and `windowScene.screen`
/// updates right away — but the existing `UIWindow`'s frame is never resized
/// to match, so SwiftUI's layout (and anything reading `GeometryReader` size)
/// stays pinned to whatever screen the window was created on. Force the
/// window to adopt the new screen's bounds whenever the connected-screen set
/// changes so layout-driven wide/compact decisions see the real size.
@MainActor
final class DuoDisplayFix {
    static let shared = DuoDisplayFix()

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(resync),
                                                 name: UIScreen.didConnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resync),
                                                 name: UIScreen.didDisconnectNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resync),
                                                 name: UIScene.didActivateNotification, object: nil)
        resync()
    }

    @objc private func resync() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene,
                  windowScene.session.role == .windowApplication else { continue }
            let target = windowScene.screen.bounds
            for window in windowScene.windows where window.frame != target {
                window.frame = target
            }
        }
    }
}
