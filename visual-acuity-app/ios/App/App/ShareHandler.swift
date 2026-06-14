import UIKit
import LinkPresentation
import WebKit

class AcuityShareItem: NSObject, UIActivityItemSource {
    private let metadata: LPLinkMetadata

    init(image: UIImage, title: String) {
        metadata = LPLinkMetadata()
        metadata.url = URL(string: "https://rjlcevans.com/eye-chart-test")!
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return metadata.url!
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return metadata.url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return metadata
    }
}

class ShareCardHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: UIViewController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let base64 = body["imageData"] as? String,
              let title = body["title"] as? String,
              let rawBase64 = base64.components(separatedBy: ",").last,
              let data = Data(base64Encoded: rawBase64),
              let image = UIImage(data: data),
              let vc = viewController else { return }

        let item = AcuityShareItem(image: image, title: title)
        let ac = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        DispatchQueue.main.async {
            var top = vc
            while let presented = top.presentedViewController { top = presented }
            top.present(ac, animated: true)
        }
    }
}

// JS sets window._shareData then fetches nativeshare://trigger — completely bypasses userContentController
class ShareSchemeHandler: NSObject, WKURLSchemeHandler {
    weak var viewController: UIViewController?

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "ShareScheme", code: 1, userInfo: nil))
            return
        }
        // CORS header required: web content at capacitor://localhost is cross-origin to nativeshare://
        let headers = ["Access-Control-Allow-Origin": "*", "Content-Type": "text/plain"]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else { return }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(Data())
        urlSchemeTask.didFinish()

        let capturedVC = viewController
        DispatchQueue.main.async {
            webView.evaluateJavaScript("(function(){ var d=window._shareData; return d?JSON.stringify(d):null; })()") { result, _ in
                guard let jsonString = result as? String,
                      let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let base64 = json["imageData"] as? String,
                      let title = json["title"] as? String,
                      let rawBase64 = base64.components(separatedBy: ",").last,
                      let imgData = Data(base64Encoded: rawBase64),
                      let image = UIImage(data: imgData),
                      let vc = capturedVC else { return }

                let item = AcuityShareItem(image: image, title: title)
                let ac = UIActivityViewController(activityItems: [item], applicationActivities: nil)
                var top = vc
                while let presented = top.presentedViewController { top = presented }
                top.present(ac, animated: true)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
