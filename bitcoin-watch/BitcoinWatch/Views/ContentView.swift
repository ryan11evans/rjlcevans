import SwiftUI
import StoreKit

struct ContentView: View {
    @EnvironmentObject var service: PriceService
    @StateObject private var statsService = StatsService.shared
    @State private var showAlertSheet = false
    @State private var hasActiveAlert = AlertService.shared.alertEnabled
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                             Color(red: 0.07, green: 0.06, blue: 0.06),
                             Color(red: 0.02, green: 0.02, blue: 0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        PriceHeaderView(price: service.currentPrice,
                                       isLoading: service.isLoading,
                                       change24h: statsService.stats?.change24h)

                        VStack(spacing: 12) {
                            BTCChartView(statsService: statsService)
                            BitcoinInfoView(stats: statsService.stats, currentPrice: service.currentPrice?.usd)
                        }
                        .padding(.horizontal)

                        RefreshStatusView(price: service.currentPrice, error: service.error)
                            .padding(.top, 16)

                        Spacer(minLength: 32)
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await service.fetchPrice()
                    await statsService.fetch()
                }
            }
            .navigationTitle("Bitcoin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task {
                await statsService.fetch()
                ReviewManager.shared.recordOpen()
                if ReviewManager.shared.shouldRequestReview {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    requestReview()
                }
            }
            .sheet(isPresented: $showAlertSheet) {
                PriceAlertView(hasActiveAlert: $hasActiveAlert)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(items: shareItems)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showAlertSheet = true } label: {
                        Image(systemName: hasActiveAlert ? "bell.fill" : "bell")
                            .foregroundStyle(hasActiveAlert ? .orange : .secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        renderAndShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(service.currentPrice == nil)
                }
            }
        }
    }

    @MainActor
    private func renderAndShare() {
        guard let price = service.currentPrice else { return }
        let card = ShareCardView(price: price, change24h: statsService.stats?.change24h)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return }
        let url = URL(string: "https://apps.apple.com/us/app/tapbtc/id6774023419")!
        shareItems = [image, url]
        showShareSheet = true
    }
}

struct PriceHeaderView: View {
    let price: BitcoinPrice?
    let isLoading: Bool
    let change24h: Double?

    @State private var flashColor: Color? = nil

    private let upColor   = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let downColor = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text("BTC / USD")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                if let price {
                    Text(price.formatted)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(flashColor ?? Color.primary)
                        .onChange(of: price.usd) { old, new in
                            let color = new > old ? upColor : downColor
                            withAnimation(.easeIn(duration: 0.1))  { flashColor = color }
                            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { flashColor = nil }
                        }
                } else {
                    Text("---")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let change = change24h {
                    ChangeBadge(change: change)
                        .padding(.bottom, 6)
                }
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

struct ChangeBadge: View {
    let change: Double
    private var isUp: Bool { change >= 0 }

    var body: some View {
        Text(String(format: "%+.1f%%", change))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(isUp ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 1, green: 0.27, blue: 0.23))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isUp
                          ? Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.15)
                          : Color(red: 1, green: 0.27, blue: 0.23).opacity(0.15))
            )
    }
}

struct RefreshStatusView: View {
    let price: BitcoinPrice?
    let error: String?

    var body: some View {
        Group {
            if let error {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
            } else if let price {
                Text("Updated ") + Text(price.timestamp, style: .relative)
            } else {
                Text("Fetching...")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
