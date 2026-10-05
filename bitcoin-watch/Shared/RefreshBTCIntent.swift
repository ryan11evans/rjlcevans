import AppIntents
import WidgetKit

// Runs in the widget extension process when the complication is tapped.
// No app launch. Fetches price, saves to shared UserDefaults, reloads timelines.
struct RefreshBTCIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Bitcoin Price"
    static var description = IntentDescription("Fetches the latest BTC/USD price from Coinbase.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // Must match the user's selected display currency — the shared
        // UserDefaults price store is read by the app/widget/Watch as-is, so
        // a hardcoded USD fetch here would silently overwrite a EUR/GBP/JPY
        // price with a raw USD number until the next real fetch corrects it.
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-\(AppCurrency.current.code)/spot"),
              let (data, _) = try? await URLSession.shared.data(from: url) else {
            return .result()
        }

        struct R: Decodable { struct D: Decodable { let amount: String }; let data: D }
        guard let r = try? JSONDecoder().decode(R.self, from: data),
              let val = Double(r.data.amount) else { return .result() }

        UserDefaults.shared.savePrice(BitcoinPrice(usd: val, timestamp: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
