import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: PriceService

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PriceHeaderView(price: service.currentPrice, isLoading: service.isLoading)
                if service.priceHistory.count > 1 {
                    PriceChartView(history: service.priceHistory)
                        .padding(.horizontal)
                }
                Spacer()
                RefreshStatusView(price: service.currentPrice, error: service.error)
                    .padding(.bottom, 12)
            }
            .navigationTitle("Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await service.fetchPrice() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(service.isLoading)
                }
            }
        }
    }
}

struct PriceHeaderView: View {
    let price: BitcoinPrice?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                Text("BTC / USD")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            if let price {
                Text(price.formatted)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text("---")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
}

struct RefreshStatusView: View {
    let price: BitcoinPrice?
    let error: String?

    private var statusText: String {
        if let error { return "Error: \(error)" }
        guard let price else { return "Fetching..." }
        let ago = Int(-price.timestamp.timeIntervalSinceNow)
        if ago < 5 { return "Just updated" }
        if ago < 60 { return "Updated \(ago)s ago" }
        return "Updated \(ago / 60)m ago"
    }

    var body: some View {
        Text(statusText)
            .font(.caption)
            .foregroundStyle(error != nil ? .red : .secondary)
    }
}
