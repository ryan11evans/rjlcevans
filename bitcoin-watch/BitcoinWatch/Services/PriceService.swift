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

    // Coinbase public API — no key required
    private let priceURL = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot")!

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

            // Keep chart right edge current on every price tick
            StatsService.shared.updateLivePrice(price.usd)

            // Fire price alert if threshold crossed (works in foreground and background)
            AlertService.shared.checkAndFire(currentPrice: price.usd)

            // Foreground-only side effects
            if UIApplication.shared.applicationState == .active {
                LiveActivityManager.shared.update(price: price.usd)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                ConnectivityManager.shared.send(price: price)
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
