import UIKit
import Capacitor

class ViewController: CAPBridgeViewController {
    private let shareHandler = ShareCardHandler()
    private var handlerRegistered = false

    override func viewDidLoad() {
        super.viewDidLoad()
        registerShareHandler()
    }

    override func capacitorDidLoad() {
        registerShareHandler()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerShareHandler()
    }

    private func registerShareHandler() {
        guard !handlerRegistered, let wv = webView else { return }
        shareHandler.viewController = self
        wv.configuration.userContentController.add(shareHandler, name: "nativeShare")
        handlerRegistered = true
    }
}
