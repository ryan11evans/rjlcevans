import Foundation
import SwiftUI

// Bitcoin vs. traditional assets — normalized % return comparison.
// Data comes from Yahoo Finance's public (unofficial, no key) chart API so
// all four series share one consistent source and methodology.
enum CompareAsset: String, CaseIterable, Identifiable {
    case bitcoin, gold, sp500, mstr

    var id: String { rawValue }

    // Path segment for the Yahoo chart endpoint (already percent-encoded).
    fileprivate var yahooSymbol: String {
        switch self {
        case .bitcoin: return "BTC-USD"
        case .gold:    return "GC=F"
        case .sp500:   return "%5EGSPC"
        case .mstr:    return "MSTR"
        }
    }

    var displayName: String {
        switch self {
        case .bitcoin: return "Bitcoin"
        case .gold:    return "Gold"
        case .sp500:   return "S&P 500"
        case .mstr:    return "MSTR"
        }
    }

    var color: Color {
        switch self {
        case .bitcoin: return .orange
        case .gold:    return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .sp500:   return Color(red: 0.35, green: 0.55, blue: 1.0)
        case .mstr:    return Color(red: 0.6, green: 0.4, blue: 1.0)
        }
    }
}

enum CompareRange: String, CaseIterable {
    case oneYear = "1Y"
    case fiveYear = "5Y"
    case all = "All"

    fileprivate var yahooRange: String {
        switch self {
        case .oneYear:  return "1y"
        case .fiveYear: return "5y"
        case .all:      return "max"
        }
    }

    // Coarser sampling for longer spans keeps the payload small.
    fileprivate var yahooInterval: String {
        switch self {
        case .oneYear:  return "1d"
        case .fiveYear: return "1wk"
        case .all:      return "1mo"
        }
    }
}

struct ComparePoint: Identifiable {
    let date: Date
    let pctChange: Double
    var id: TimeInterval { date.timeIntervalSince1970 }
}

@MainActor
final class CompareService: ObservableObject {
    static let shared = CompareService()

    @Published var seriesByAsset: [CompareAsset: [ComparePoint]] = [:]
    @Published var isLoading = false
    @Published var errorAssets: Set<CompareAsset> = []

    func fetch(assets: [CompareAsset], range: CompareRange) async {
        isLoading = true
        errorAssets = []
        await withTaskGroup(of: (CompareAsset, [ComparePoint]?).self) { group in
            for asset in assets {
                group.addTask {
                    (asset, await Self.fetchSeries(asset: asset, range: range))
                }
            }
            for await (asset, points) in group {
                if let points, !points.isEmpty {
                    seriesByAsset[asset] = points
                } else {
                    errorAssets.insert(asset)
                }
            }
        }
        isLoading = false
    }

    private static func fetchSeries(asset: CompareAsset, range: CompareRange) async -> [ComparePoint]? {
        guard let raw = await fetchRawCloses(asset: asset, range: range),
              let firstClose = raw.first?.close, firstClose > 0
        else { return nil }

        return raw.map { point in
            ComparePoint(date: point.date, pctChange: (point.close / firstClose - 1) * 100)
        }
    }

    // Raw (date, close) pairs — used directly by features that need actual
    // price levels rather than a % return normalized to the fetch's start.
    static func fetchRawCloses(asset: CompareAsset, range: CompareRange) async -> [(date: Date, close: Double)]? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(asset.yahooSymbol)?range=\(range.yahooRange)&interval=\(range.yahooInterval)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        struct Response: Decodable {
            struct Chart: Decodable {
                struct Result: Decodable {
                    struct Indicators: Decodable {
                        struct Quote: Decodable { let close: [Double?] }
                        let quote: [Quote]
                    }
                    let timestamp: [Int]
                    let indicators: Indicators
                }
                let result: [Result]?
            }
            let chart: Chart
        }

        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let result = decoded.chart.result?.first,
              let closes = result.indicators.quote.first?.close
        else { return nil }

        return zip(result.timestamp, closes).compactMap { timestamp, close in
            guard let close else { return nil }
            return (Date(timeIntervalSince1970: TimeInterval(timestamp)), close)
        }
    }
}
