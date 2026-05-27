import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var service: WatchPriceService
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                Text("BTC / USD")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let price = service.currentPrice {
                Text(price.shortFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(price.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                if service.isLoading {
                    ProgressView()
                } else {
                    Text("---")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await service.fetchDirect() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(service.isLoading)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                service.startForegroundRefresh()
            } else {
                service.stopForegroundRefresh()
            }
        }
    }
}
