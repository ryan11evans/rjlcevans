import UIKit
import Capacitor

/// Hosts the Capacitor bridge for the UIScene lifecycle required by the iOS 27 SDK.
/// Main.storyboard (UISceneStoryboardFile) is the window's root: CAPBridgeViewController.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // The storyboard normally installs the window before this runs. If it
        // did not, build the same one so the bridge still has a host.
        if window == nil {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
            self.window = window
            window.makeKeyAndVisible()
        }

        // Cold start. UIKit does not also deliver these through the later scene methods.
        for context in connectionOptions.urlContexts {
            forward(url: context.url, options: context.options)
        }
        for activity in connectionOptions.userActivities {
            forward(activity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            forward(url: context.url, options: context.options)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        forward(userActivity)
    }

    private func forward(url: URL, options: UIScene.OpenURLOptions) {
        var openOptions: [UIApplication.OpenURLOptionsKey: Any] = [:]
        if let source = options.sourceApplication {
            openOptions[.sourceApplication] = source
        }
        if let annotation = options.annotation {
            openOptions[.annotation] = annotation
        }
        openOptions[.openInPlace] = options.openInPlace
        _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, open: url, options: openOptions)
    }

    private func forward(_ userActivity: NSUserActivity) {
        _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, continue: userActivity) { _ in }
    }
}
