import UIKit
import Capacitor

class ViewController: CAPBridgeViewController {
    private let shareHandler = ShareCardHandler()

    override func capacitorDidLoad() {
        shareHandler.viewController = self
        webView?.configuration.userContentController.add(shareHandler, name: "nativeShare")
    }
}
