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
