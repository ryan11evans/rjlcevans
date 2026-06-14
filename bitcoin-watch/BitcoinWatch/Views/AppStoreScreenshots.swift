#if DEBUG
import SwiftUI
import Charts

// MARK: - Static mock data (fixed values = consistent screenshots)

private let mockChartData: [(Date, Double)] = {
    let now = Date()
    let prices: [Double] = [
        103_420, 103_890, 104_230, 104_050, 103_780, 104_510,
        104_890, 105_230, 104_980, 105_670, 106_120, 105_890,
        106_340, 106_780, 107_050, 106_820, 107_180, 107_420,
        107_090, 106_940, 107_310, 107_580, 107_240, 107_324
    ]
    return prices.enumerated().map { i, p in
        (now.addingTimeInterval(Double(i - 23) * 3600), p)
    }
}()

private let bgColors = [
    Color(red: 0.12, green: 0.11, blue: 0.10),
    Color(red: 0.07, green: 0.06, blue: 0.06),
    Color(red: 0.02, green: 0.02, blue: 0.02)
]
private let upColor   = Color(red: 0.19, green: 0.82, blue: 0.35)
private let downColor = Color(red: 1.00, green: 0.27, blue: 0.23)

// MARK: - Shared helpers

private struct ScreenshotBG: View {
    var body: some View {
        LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

private struct ScreenshotCaption: View {
    let title: String
    let subtitle: String
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.96)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 52)
            .padding(.horizontal, 28)
        }
    }
}

private struct FakeNavBar: View {
    var body: some View {
        HStack {
            Image(systemName: "bell")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Bitcoin")
                .font(.headline)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 12)
    }
}

private struct PriceHeader: View {
    var price: String = "$107,324"
    var change: String = "+3.47%"
    var isUp: Bool = true
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.orange)
                Text("BTC / USD")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.top, 20)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(price)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(change)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isUp ? upColor : downColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((isUp ? upColor : downColor).opacity(0.15))
                    )
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }
}

private struct MiniLineChart: View {
    var points: [(Date, Double)] = mockChartData
    var color: Color = upColor
    var height: CGFloat = 140
    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                LineMark(x: .value("T", pt.0), y: .value("P", pt.1))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                AreaMark(x: .value("T", pt.0), y: .value("P", pt.1))
                    .foregroundStyle(LinearGradient(
                        colors: [color.opacity(0.28), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(height: height)
    }
}

// MARK: - Screenshot 1: Live price hero

struct SS1_LivePrice: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotBG()
            VStack(spacing: 0) {
                FakeNavBar()
                PriceHeader()
                MiniLineChart().padding(.horizontal, 16)
                VStack(spacing: 0) {
                    ForEach([
                        ("arrow.up", "24h High", "$109,150", upColor),
                        ("arrow.down", "24h Low", "$103,420", downColor),
                        ("trophy.fill", "All-Time High", "$109,588", Color.orange),
                        ("cube.fill", "Block Height", "901,432", Color(white: 0.55)),
                    ], id: \.1) { icon, label, value, color in
                        HStack {
                            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
                            Text(label).foregroundStyle(.secondary)
                            Spacer()
                            Text(value).fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        Divider().padding(.horizontal, 20).opacity(0.2)
                    }
                }
                .padding(.top, 8)
                Spacer()
            }
            ScreenshotCaption(
                title: "Bitcoin. Always live.",
                subtitle: "Real-time price · Updates every 30 seconds"
            )
        }
        .frame(width: 393, height: 852)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screenshot 2: Chart touch scrubbing

struct SS2_ChartTouch: View {
    private let selectedIdx = 17
    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotBG()
            VStack(spacing: 0) {
                FakeNavBar()
                PriceHeader(price: "$107,420", change: "+3.47%")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("$107,420")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("6 hrs ago")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(["1D", "7D", "30D"], id: \.self) { r in
                                Text(r)
                                    .font(.system(size: 12, weight: r == "1D" ? .bold : .regular))
                                    .foregroundStyle(r == "1D" ? .white : .secondary)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(
                                        r == "1D"
                                            ? AnyView(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.15)))
                                            : AnyView(Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    Chart {
                        ForEach(Array(mockChartData.enumerated()), id: \.offset) { i, pt in
                            LineMark(x: .value("T", pt.0), y: .value("P", pt.1))
                                .foregroundStyle(upColor).lineStyle(StrokeStyle(lineWidth: 2))
                            AreaMark(x: .value("T", pt.0), y: .value("P", pt.1))
                                .foregroundStyle(LinearGradient(
                                    colors: [upColor.opacity(0.28), .clear],
                                    startPoint: .top, endPoint: .bottom
                                ))
                        }
                        RuleMark(x: .value("T", mockChartData[selectedIdx].0))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        PointMark(
                            x: .value("T", mockChartData[selectedIdx].0),
                            y: .value("P", mockChartData[selectedIdx].1)
                        )
                        .foregroundStyle(.white).symbolSize(70)
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden)
                    .frame(height: 220)
                    .padding(.horizontal, 16)
                }
                Spacer()
            }
            ScreenshotCaption(
                title: "Touch the chart.",
                subtitle: "Scrub any point to see the exact price and time"
            )
        }
        .frame(width: 393, height: 852)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screenshot 3: Price alerts

struct SS3_Alerts: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotBG()
            VStack(spacing: 0) {
                FakeNavBar()
                PriceHeader()
                // Alert sheet card
                VStack(spacing: 0) {
                    // Sheet drag indicator
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    HStack {
                        Text("Price Alert")
                            .font(.title3.bold())
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary).font(.title3)
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
                    Divider().opacity(0.25).padding(.horizontal, 20)
                    VStack(spacing: 18) {
                        HStack {
                            Text("Alert when price goes")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        Picker("", selection: .constant(0)) {
                            Text("Above").tag(0)
                            Text("Below").tag(1)
                        }
                        .pickerStyle(.segmented).padding(.horizontal, 20)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TARGET PRICE (USD)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            HStack {
                                Text("$").foregroundStyle(.secondary)
                                Text("110,000").fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "keyboard").foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .padding(.horizontal, 20)
                        }
                        Button { } label: {
                            Text("Set Alert")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 14).padding(.bottom, 24)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 0.16, green: 0.15, blue: 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                Spacer()
            }
            ScreenshotCaption(
                title: "Never miss a move.",
                subtitle: "Instant notification when BTC hits your target"
            )
        }
        .frame(width: 393, height: 852)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screenshot 4: Dynamic Island + Live Activity

struct SS4_LiveActivity: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotBG()
            VStack(spacing: 0) {
                // Status bar area
                HStack {
                    Text("9:41")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "cellularbars")
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100")
                    }
                    .font(.system(size: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                // Dynamic Island mockup
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .frame(width: 340, height: 62)
                    HStack(spacing: 0) {
                        // Leading: ₿ icon
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 22))
                            .padding(.leading, 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("BITCOIN")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("$107,324")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .padding(.leading, 8)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+3.47%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(upColor)
                            Text("just now")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.trailing, 16)
                    }
                    .frame(width: 340)
                }
                .padding(.top, 8)

                // Lock screen live activity banner
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.85))
                    HStack(spacing: 14) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bitcoin")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("$107,324")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+3.47%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(upColor)
                            Text("just now")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                .frame(height: 80)
                .padding(.horizontal, 16)
                .padding(.top, 20)

                // Small label
                Text("Live Activity · Dynamic Island")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                Spacer()
            }
            ScreenshotCaption(
                title: "Always in view.",
                subtitle: "Live Activity on lock screen · Dynamic Island"
            )
        }
        .frame(width: 393, height: 852)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Screenshot 5: Apple Watch

struct SS5_AppleWatch: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenshotBG()
            VStack(spacing: 0) {
                Spacer().frame(height: 70)
                // Watch body
                ZStack {
                    // Band top
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.18))
                        .frame(width: 130, height: 50)
                        .offset(y: -130)
                    // Band bottom
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(white: 0.18))
                        .frame(width: 130, height: 50)
                        .offset(y: 130)
                    // Watch case
                    RoundedRectangle(cornerRadius: 44)
                        .fill(Color(white: 0.10))
                        .frame(width: 186, height: 224)
                        .overlay(
                            RoundedRectangle(cornerRadius: 44)
                                .stroke(Color(white: 0.28), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.7), radius: 30, y: 8)
                    // Crown
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.3))
                        .frame(width: 6, height: 38)
                        .offset(x: 94, y: -18)
                    // Screen
                    RoundedRectangle(cornerRadius: 38)
                        .fill(Color.black)
                        .frame(width: 170, height: 208)
                        .overlay {
                            VStack(spacing: 5) {
                                HStack(spacing: 4) {
                                    Image(systemName: "bitcoinsign.circle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption2)
                                    Text("BTC / USD")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(.top, 8)
                                Text("$107K")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("+3.47%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(upColor)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(upColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                                // Sparkline
                                Chart {
                                    ForEach(Array(mockChartData.suffix(12).enumerated()), id: \.offset) { i, pt in
                                        LineMark(x: .value("T", Double(i)), y: .value("P", pt.1))
                                            .foregroundStyle(upColor)
                                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                                        AreaMark(x: .value("T", Double(i)), y: .value("P", pt.1))
                                            .foregroundStyle(LinearGradient(
                                                colors: [upColor.opacity(0.25), .clear],
                                                startPoint: .top, endPoint: .bottom
                                            ))
                                    }
                                }
                                .chartXAxis(.hidden).chartYAxis(.hidden)
                                .frame(height: 50)
                                .padding(.horizontal, 12)
                                Text("just now")
                                    .font(.system(size: 10)).foregroundStyle(.secondary)
                                    .padding(.bottom, 8)
                            }
                        }
                }
                .frame(height: 320)
                Spacer()
            }
            ScreenshotCaption(
                title: "Your wrist. Your price.",
                subtitle: "Full Apple Watch app · Chart · Live stats"
            )
        }
        .frame(width: 393, height: 852)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews
// Capture: right-click preview canvas → Save Current Preview As Image
// Or: run in iPhone 16 Pro Max simulator → ⌘S to screenshot

#Preview("1 · Live Price")     { SS1_LivePrice() }
#Preview("2 · Chart Touch")    { SS2_ChartTouch() }
#Preview("3 · Price Alerts")   { SS3_Alerts() }
#Preview("4 · Live Activity")  { SS4_LiveActivity() }
#Preview("5 · Apple Watch")    { SS5_AppleWatch() }

#endif
