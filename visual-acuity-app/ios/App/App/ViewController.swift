import UIKit
import Capacitor
import WebKit

class ViewController: CAPBridgeViewController {
    private let shareHandler = ShareCardHandler()

    override func webView(with frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
        shareHandler.viewController = self
        configuration.userContentController.add(shareHandler, name: "nativeShare")
        return super.webView(with: frame, configuration: configuration)
    }
}
