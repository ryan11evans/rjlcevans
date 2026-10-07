import SwiftUI
import UIKit

/// Local mirror of `UIHinge.Status` so call sites don't need `@available` guards just to read state.
enum HingeState {
    case unavailable
    case closed
    case partiallyOpen
    case fullyOpen
}

/// Bridges UIKit's `UIHingeInteraction` (iOS 27.1+, foldable devices) into SwiftUI.
/// On devices/OS versions without a hinge, `state` stays `.unavailable` and callers
/// should fall back to size-class/width-based layout decisions (e.g. for iPad).
@MainActor
final class HingeObserver: NSObject, ObservableObject {
    @Published private(set) var state: HingeState = .unavailable
    private var interactionToken: AnyObject?

    func attach(to view: UIView) {
        guard interactionToken == nil else { return }
        if #available(iOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak self] _, update in
                let mapped = Self.map(update.hinge?.status)
                Task { @MainActor in
                    self?.state = mapped
                }
            }
            view.addInteraction(interaction)
            interactionToken = interaction
        }
    }

    @available(iOS 27.1, *)
    private static func map(_ status: UIHinge.Status?) -> HingeState {
        switch status {
        case .closed: return .closed
        case .partiallyOpen: return .partiallyOpen
        case .fullyOpen: return .fullyOpen
        default: return .unavailable
        }
    }
}

/// Invisible view that attaches the hinge interaction so SwiftUI can observe live fold state.
struct HingeReader: UIViewRepresentable {
    @ObservedObject var observer: HingeObserver

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        observer.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
