import Foundation
import WatchConnectivity
import ClockKit

// Receives price pushes from the iPhone.
// iPhone uses transferCurrentComplicationUserInfo() which is highest-priority —
// watchOS wakes the app and delivers the payload even in background.
class WatchConnectivityReceiver: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityReceiver()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Live message when Watch app is open and iPhone is reachable
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(payload: message)
    }

    // Background user info (non-complication path)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(payload: userInfo)
    }

    // Complication user info — highest priority, wakes app
    func session(_ session: WCSession, didReceiveCurrentComplicationUserInfo userInfo: [String: Any]) {
        handle(payload: userInfo)
    }

    // Latest-state channel — carries holdings + Pro when they change on the phone
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyHoldings(from: applicationContext)
    }

    private func handle(payload: [String: Any]) {
        applyHoldings(from: payload)
        guard let usd = payload[WCMessageKey.price] as? Double,
              let ts = payload[WCMessageKey.timestamp] as? TimeInterval else { return }
        let price = BitcoinPrice(usd: usd, timestamp: Date(timeIntervalSince1970: ts))
        Task { @MainActor in
            WatchPriceService.shared.update(price: price)
        }
    }

    private func applyHoldings(from payload: [String: Any]) {
        guard let amount = payload[WCMessageKey.holdings] as? Double,
              let isPro = payload[WCMessageKey.isPro] as? Bool else { return }
        Task { @MainActor in
            WatchPriceService.shared.updateHoldings(amount: amount, isPro: isPro)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}
