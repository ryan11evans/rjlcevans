#if os(iOS)
import ActivityKit
import Foundation

struct BTCLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let price: Double
        let change24h: Double?
        let timestamp: Date
    }
}
#endif
