import UIKit
import Capacitor
import WebKit

class ViewController: CAPBridgeViewController {
    private let shareHandler = ShareCardHandler()
    private let schemeHandler = ShareSchemeHandler()

    override func webView(with frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
        shareHandler.viewController = self
        schemeHandler.viewController = self
        configuration.userContentController.add(shareHandler, name: "nativeShare")
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "nativeshare")
        // Diagnostic: confirm this override fires and both bridges are wired
        let diag = WKUserScript(
            source: "console.log('[VC] nativeShare=' + !!(window.webkit?.messageHandlers?.nativeShare) + ' Capacitor=' + !!window.Capacitor);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(diag)
        return super.webView(with: frame, configuration: configuration)
    }
}
