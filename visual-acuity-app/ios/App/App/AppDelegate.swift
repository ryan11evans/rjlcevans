import UIKit
import WebKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let shareHandler = ShareCardHandler()
    private var handlerRegistered = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Retry on each activation until the WKWebView is in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.injectShareHandler()
        }
    }

    private func injectShareHandler() {
        guard !handlerRegistered,
              let rootVC = window?.rootViewController else { return }

        guard let wv = findWebView(in: rootVC.view) else { return }

        shareHandler.viewController = rootVC
        wv.configuration.userContentController.add(shareHandler, name: "nativeShare")
        handlerRegistered = true
    }

    private func findWebView(in view: UIView) -> WKWebView? {
        if let wv = view as? WKWebView { return wv }
        for sub in view.subviews {
            if let wv = findWebView(in: sub) { return wv }
        }
        return nil
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
