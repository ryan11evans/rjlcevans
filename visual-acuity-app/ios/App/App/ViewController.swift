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
        return super.webView(with: frame, configuration: configuration)
    }
}
