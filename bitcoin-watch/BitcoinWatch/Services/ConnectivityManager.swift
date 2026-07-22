import Foundation
import WatchConnectivity

// Pushes price updates from iPhone → Watch.
// Uses transferCurrentComplicationUserInfo() which has its own 50/day budget
// separate from regular messages, and is delivered with complication priority.
class ConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = ConnectivityManager()

    private var session: WCSession?
    private var lastSentPrice: Double = 0
    private let minChangePct = 0.001  // Only push if price moved >0.1% to save budget

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    func send(price: BitcoinPrice) {
        guard let session, session.activationState == .activated, session.isPaired else { return }

        // Rate-limit: skip if price barely moved (saves Watch complication budget)
        let pctChange = abs(price.usd - lastSentPrice) / max(lastSentPrice, 1)
        guard lastSentPrice == 0 || pctChange >= minChangePct else { return }
        lastSentPrice = price.usd

        let payload: [String: Any] = [
            WCMessageKey.price: price.usd,
            WCMessageKey.timestamp: price.timestamp.timeIntervalSince1970,
            WCMessageKey.holdings: UserDefaults.shared.double(forKey: "btcHoldings"),
            WCMessageKey.isPro: UserDefaults.shared.bool(forKey: "isProUnlocked"),
            WCMessageKey.currency: AppCurrency.current.rawValue
        ]

        if session.isComplicationEnabled {
            // Highest-priority delivery path — triggers immediate complication reload
            session.transferCurrentComplicationUserInfo(payload)
        } else if session.isReachable {
            // Watch app is open: send live message
            session.sendMessage(payload, replyHandler: nil)
        } else {
            // Background transfer — arrives when Watch wakes
            session.transferUserInfo(payload)
        }
    }

    /// Push holdings + Pro state to the Watch immediately (used when they change
    /// while the price is static, so the price-piggyback path wouldn't fire).
    func syncHoldings() {
        guard let session, session.activationState == .activated, session.isPaired else { return }
        let context: [String: Any] = [
            WCMessageKey.holdings: UserDefaults.shared.double(forKey: "btcHoldings"),
            WCMessageKey.isPro: UserDefaults.shared.bool(forKey: "isProUnlocked"),
            WCMessageKey.currency: AppCurrency.current.rawValue
        ]
        try? session.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate (required)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
