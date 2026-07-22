import Capacitor
import LinkPresentation
import UIKit

@objc(SharePlugin)
public class SharePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SharePlugin"
    public let jsName = "SharePlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "shareResult", returnType: CAPPluginReturnPromise)
    ]

    @objc func shareResult(_ call: CAPPluginCall) {
        let imageData = call.getString("imageData") ?? ""
        let title = call.getString("title") ?? "My Vision Results"

        guard let rawBase64 = imageData.components(separatedBy: ",").last,
              let data = Data(base64Encoded: rawBase64),
              let image = UIImage(data: data) else {
            call.reject("Invalid image data")
            return
        }

        let item = AcuityShareItem(image: image, title: title)
        let ac = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        DispatchQueue.main.async { [weak self] in
            guard let vc = self?.bridge?.viewController else {
                call.reject("No view controller")
                return
            }
            if let pop = ac.popoverPresentationController {
                pop.sourceView = vc.view
                pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                pop.permittedArrowDirections = []
            }
            vc.present(ac, animated: true) {
                call.resolve()
            }
        }
    }
}
