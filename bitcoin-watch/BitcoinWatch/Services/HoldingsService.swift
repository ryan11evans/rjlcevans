import Foundation
import WidgetKit

// Stores how much BTC the user holds, locally in the shared app group so the
// widget and Watch can read it too. No account, no cloud — just a number.
@MainActor
final class HoldingsService: ObservableObject {
    static let shared = HoldingsService()

    @Published private(set) var amount: Double

    private let key = "btcHoldings"

    init() {
        amount = UserDefaults.shared.double(forKey: key)
    }

    var hasHoldings: Bool { amount > 0 }

    func value(at price: Double) -> Double { amount * price }

    func setAmount(_ newValue: Double) {
        amount = max(0, newValue)
        UserDefaults.shared.set(amount, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await PushService.shared.sync() }
    }

    /// Formatted BTC amount, trimming trailing zeros (e.g. "0.42", "1.5").
    var formattedAmount: String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
