import SwiftUI

private let appStoreURL = "apps.apple.com/us/app/tapbtc/id6774023419"

struct ShareCardView: View {
    let price: BitcoinPrice
    let change24h: Double?

    private var changeColor: Color {
        (change24h ?? 0) >= 0
            ? Color(red: 0.19, green: 0.82, blue: 0.35)
            : Color(red: 1, green: 0.27, blue: 0.23)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.13, blue: 0.12),
                         Color(red: 0.07, green: 0.06, blue: 0.06),
                         Color(red: 0.02, green: 0.02, blue: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 16))
                        Text("Bitcoin")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("TapBTC")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                Spacer()

                // Price
                VStack(spacing: 10) {
                    Text(price.formatted)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)

                    if let change = change24h {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(changeColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(changeColor.opacity(0.15))
                            )
                    }
                }

                Spacer()

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 22)

                // Footer
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Bitcoin price")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(appStoreURL)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Spacer()

                    // App Store badge
                    HStack(spacing: 5) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: -1) {
                            Text("Download on the")
                                .font(.system(size: 7.5, weight: .regular))
                                .foregroundStyle(.white)
                            Text("App Store")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 375, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// UIKit share sheet wrapper
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
