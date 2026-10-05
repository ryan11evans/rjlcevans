import Foundation
import Combine
import WidgetKit
import UIKit

@MainActor
class PriceService: ObservableObject {
    static let shared = PriceService()

    @Published var currentPrice: BitcoinPrice?
    @Published var priceHistory: [BitcoinPrice] = []
    @Published var isLoading = false
    @Published var error: String?

    private var refreshTask: Task<Void, Never>?
    private var foregroundInterval: TimeInterval = 15  // 15 seconds when app is open
    private let maxHistoryCount = 288  // 24 hours at 5-min intervals

    // Coinbase public API — no key required. Currency-aware.
    private var priceURL: URL {
        URL(string: "https://api.coinbase.com/v2/prices/BTC-\(AppCurrency.current.code)/spot")!
    }

    init() {
        // Restore last known price immediately so UI never shows blank
        if let saved = UserDefaults.shared.loadPrice() {
            currentPrice = saved
        }
    }

    func startForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await fetchPrice()
                try? await Task.sleep(nanoseconds: UInt64(foregroundInterval * 1_000_000_000))
            }
        }
    }

    func stopForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    @discardableResult
    func fetchPrice() async -> BitcoinPrice? {
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: priceURL)
            let response = try JSONDecoder().decode(CoinbaseResponse.self, from: data)
            let price = BitcoinPrice(usd: response.data.amount, timestamp: Date())

            currentPrice = price
            error = nil

            // Append to history, keeping max count
            priceHistory.append(price)
            if priceHistory.count > maxHistoryCount {
                priceHistory.removeFirst(priceHistory.count - maxHistoryCount)
            }

            // Persist for widget + Watch
            UserDefaults.shared.savePrice(price)

            // Tell WidgetKit to reload so the lock screen / home screen widget shows fresh data
            WidgetCenter.shared.reloadAllTimelines()

            // Fire price alert if threshold crossed (works in foreground and background)
            AlertService.shared.checkAndFire(currentPrice: price.usd)

            // Live Activity must keep updating in the background too — it's the whole
            // point of the Dynamic Island / lock-screen card. Gating this to foreground
            // only meant it went stale the moment the app was backgrounded, even though
            // BackgroundRefresh was still fetching fresh prices every ~10-15 min.
            LiveActivityManager.shared.update(price: price.usd)

            // Foreground-only side effects
            if UIApplication.shared.applicationState == .active {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                ConnectivityManager.shared.send(price: price)
                // Keep the 1D chart's right edge moving every 15s like the
                // header price. This call went missing at some point (the
                // function and its "called every 15s" doc comment were still
                // sitting in StatsService with zero call sites) — without it
                // the chart only moved on the 5-min auto-refresh.
                StatsService.shared.updateLivePrice(price.usd)
            }

            return price
        } catch {
            if (error as? URLError)?.code == .cancelled { return nil }
            self.error = error.localizedDescription
            return nil
        }
    }
}

// Coinbase v2 response shape
private struct CoinbaseResponse: Decodable {
    struct Data: Decodable {
        let amount: Double

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try container.decode(String.self, forKey: .amount)
            guard let value = Double(raw) else {
                throw DecodingError.dataCorruptedError(forKey: .amount, in: container, debugDescription: "Non-numeric amount")
            }
            amount = value
        }

        enum CodingKeys: String, CodingKey { case amount }
    }
    let data: Data
}
