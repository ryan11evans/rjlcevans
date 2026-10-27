import SwiftUI

// Presents PaywallView from the root, and asks the holdings editor to close
// first when a widget deep link arrives on top of that sheet.
@MainActor
final class PaywallRouter: ObservableObject {
    static let shared = PaywallRouter()
    @Published var trigger: PaywallTrigger?
    @Published var dismissEditorToken = 0
    /// True from the moment the holdings sheet appears until the user dismisses it.
    /// Not cleared on background, so a Home Screen tap can still find it.
    var editorOpen = false
}

// Live stack numbers from the app-group defaults the widget already reads,
// so the paywall preview matches what Pro would put on the Home Screen.
struct StackSnapshot {
    let value: Double?
    let gainPct: Double?
    let btcPrice: Double?

    static var current: StackSnapshot {
        let amount = UserDefaults.shared.double(forKey: "btcHoldings")
        let price = UserDefaults.shared.loadPrice()?.usd
        let invested = UserDefaults.shared.double(forKey: "btcInvestedBTC")
        let basis = UserDefaults.shared.double(forKey: "btcTotalInvested")
        let value: Double? = (amount > 0 && (price ?? 0) > 0) ? amount * price! : nil
        let gain: Double? = {
            guard invested > 0, basis > 0, let price, price > 0 else { return nil }
            return (invested * price) / basis - 1
        }()
        return StackSnapshot(value: value, gainPct: gain, btcPrice: (price ?? 0) > 0 ? price : nil)
    }

    var valueText: String? { value.map { AppCurrency.current.format($0) } }
    var btcShort: String? { btcPrice.map { AppCurrency.current.formatShort($0) } }

    /// Live stack when the user holds bitcoin and we have a price. Otherwise a
    /// sample 0.15 BTC so a first-launch preview still looks like My Stack.
    /// Holders with no price yet keep the empty state — we don't invent a value.
    static func liveOrSample() -> (snapshot: StackSnapshot, isSample: Bool) {
        let live = current
        if live.value != nil { return (live, false) }
        if UserDefaults.shared.double(forKey: "btcHoldings") > 0 {
            return (live, false)
        }
        let price = live.btcPrice ?? 100_000
        return (StackSnapshot(value: price * 0.15, gainPct: 0.124, btcPrice: price), true)
    }
}

extension PaywallTrigger {
    var symbol: String {
        switch self {
        case .settings:   return "bolt.fill"
        case .widget:     return "square.grid.2x2.fill"
        case .holdings:   return "chart.pie.fill"
        case .alerts:     return "bell.badge.fill"
        case .volatility: return "waveform.path.ecg"
        case .briefing:   return "sun.max.fill"
        case .icon:       return "app.badge.fill"
        case .theme:      return "paintpalette.fill"
        case .onboarding: return "sparkles"
        }
    }

    /// Feature row to lead with. Matches the control the user just tapped.
    var featureID: String {
        switch self {
        case .settings, .widget, .holdings, .onboarding: return "stack"
        case .volatility: return "volatility"
        case .briefing:   return "briefing"
        case .alerts:     return "alerts"
        case .icon:       return "icon"
        case .theme:      return "theme"
        }
    }

    func headline(stack: String?) -> String {
        guard let stack else { return plainHeadline }
        switch self {
        case .widget, .settings, .onboarding:
            return "Your \(stack) stack, on your Home Screen"
        case .holdings:
            return "Your \(stack) stack, everywhere"
        case .briefing:
            return "Your \(stack) stack, every morning"
        case .alerts:
            return "Unlimited alerts for your \(stack) stack"
        case .volatility:
            return "Pings when your \(stack) stack moves"
        case .icon:
            return "Icons worthy of your \(stack) stack"
        case .theme:
            return "A widget theme for your \(stack) stack"
        }
    }

    var plainHeadline: String {
        switch self {
        case .widget:     return "Your stack, on your Home Screen"
        case .holdings:   return "Put your stack everywhere"
        case .settings:   return "Your stack, everywhere you look"
        case .briefing:   return "Wake up to your stack"
        case .alerts:     return "Unlimited price alerts"
        case .volatility: return "Catch the big moves"
        case .icon:       return "Exclusive app icons"
        case .theme:      return "Widget themes"
        case .onboarding: return "Your stack, on your Home Screen and Watch"
        }
    }

    func subtitle(stack: String?) -> String {
        switch self {
        case .widget:
            return "Pro puts this number on My Stack, your Watch, and the daily briefing."
        case .onboarding:
            return "One-time Pro puts this on My Stack and your Watch. No subscription."
        case .holdings:
            return "One unlock puts it on your Home Screen, Watch, and morning briefing."
        case .settings:
            return "Home Screen, Apple Watch, and a daily briefing — one time, yours forever."
        case .briefing:
            if let stack {
                return "One morning push with the price, the 24h move, and your \(stack) stack."
            }
            return "One morning push: price, the 24h move, and your stack."
        case .alerts:
            if let stack {
                return "Free includes one alert. Pro covers every target on your \(stack) stack."
            }
            return "Free includes one alert. Pro removes the cap."
        case .volatility:
            return "Get pinged when BTC makes a big move in a day."
        case .icon:
            return "Unlock Gold, Midnight, Emerald, and Rose."
        case .theme:
            return "Color your Home Screen widget to match your icon."
        }
    }
}

struct PaywallView: View {
    var trigger: PaywallTrigger = .settings

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pro = ProService.shared
    @State private var purchasing = false
    @State private var restoring = false
    @State private var showThanks = false
    /// Full thank-you, swapped in for the paywall so it isn't a second
    /// presentation fighting this sheet's dismissal (or the stack-everywhere
    /// sheet underneath it).
    @State private var showPurchaseThanks = false
    @State private var alert: PaywallAlert?

    private var stack: StackSnapshot { StackSnapshot.current }

    var body: some View {
        Group {
            if showPurchaseThanks {
                ProThanksView { dismiss() }
                    .adaptiveSheetSizing(.page)
            } else {
                paywallContent
            }
        }
        .interactiveDismissDisabled(showPurchaseThanks)
        .presentationDragIndicator(showPurchaseThanks ? .hidden : .automatic)
        .preferredColorScheme(.dark)
    }

    private var paywallContent: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            hero
                            StackSurfacesPreview(
                                stackText: stack.valueText,
                                gainPct: stack.gainPct,
                                btcText: stack.btcShort
                            )
                            featureList
                        }
                        .padding(.bottom, 12)
                        .readableWidth()
                    }

                    purchaseBar
                }
            }
            .adaptiveSheetSizing(.page)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            // Restore, and a purchase that already walked through the
            // thank-you. A first purchase swaps in ProThanksView instead.
            .alert("You're Pro! ⚡️", isPresented: $showThanks) {
                Button("Let's go") { dismiss() }
            } message: {
                Text("Thanks for supporting TapBTC. Your stack is unlocked on the Home Screen, Watch, and daily briefing.")
            }
            .alert(
                alert?.title ?? "TapBTC Pro",
                isPresented: Binding(
                    get: { alert != nil },
                    set: { if !$0 { alert = nil } }
                )
            ) {
                if alert != nil {
                    Button("Retry") { retryAlert() }
                }
                Button("OK", role: .cancel) { alert = nil }
            } message: {
                Text(alert?.message ?? "")
            }
            .task {
                if pro.product == nil { await pro.refresh() }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: trigger.symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.orange)
            }
            Text(trigger.headline(stack: stack.valueText))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text(trigger.subtitle(stack: stack.valueText))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("One-time purchase. Yours forever.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
    }

    private var featureList: some View {
        let features = orderedFeatures
        return VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                featureRow(feature, lead: index == 0)
                if index < features.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private var orderedFeatures: [ProFeature] {
        let all: [ProFeature] = [
            .init(id: "stack", icon: "chart.pie.fill",
                  title: "Portfolio on your Home Screen",
                  subtitle: "Your Bitcoin's live value on the widget, Watch & Lock Screen"),
            .init(id: "volatility", icon: "waveform.path.ecg",
                  title: "Volatility alerts",
                  subtitle: "Get pinged when BTC makes a big move in a day"),
            .init(id: "briefing", icon: "sun.max.fill",
                  title: "Daily briefing",
                  subtitle: "One morning push: price, 24h move & your stack"),
            .init(id: "alerts", icon: "bell.badge.fill",
                  title: "Unlimited price alerts",
                  subtitle: "Free includes one alert — Pro removes the cap"),
            .init(id: "icon", icon: "app.badge.fill",
                  title: "Exclusive app icons",
                  subtitle: "Unlock Gold, Midnight, Emerald & Rose"),
            .init(id: "theme", icon: "paintpalette.fill",
                  title: "Widget themes",
                  subtitle: "Color your Home Screen widget to match your icon"),
        ]
        let lead = trigger.featureID
        return all.sorted { ($0.id == lead ? 0 : 1) < ($1.id == lead ? 0 : 1) }
    }

    private func featureRow(_ feature: ProFeature, lead: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                Text(feature.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if lead {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var purchaseBar: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                Group {
                    if purchasing || (pro.isLoadingProduct && pro.product == nil) {
                        ProgressView().tint(.black)
                    } else if let price = pro.displayPrice {
                        Text("Unlock Pro · \(price)")
                            .font(.system(.body, weight: .bold))
                    } else {
                        Text("Unlock Pro")
                            .font(.system(.body, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                .foregroundStyle(.black)
            }
            .disabled(purchasing || restoring || pro.product == nil)
            .opacity(pro.product == nil && !pro.isLoadingProduct && !purchasing ? 0.45 : 1)

            if pro.product == nil && !purchasing {
                VStack(spacing: 4) {
                    Text(pro.productLoadFailed
                         ? "Couldn't load Pro from the App Store."
                         : "Loading App Store price…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if pro.productLoadFailed && !pro.isLoadingProduct {
                        Button("Try Again") { Task { await pro.refresh() } }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Button {
                Task { await restorePurchases() }
            } label: {
                if restoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .disabled(purchasing || restoring)
        }
        .padding(20)
        .readableWidth()
    }

    private func buy() async {
        purchasing = true
        defer { purchasing = false }
        switch await pro.purchase() {
        case .success:
            if ProPurchaseThanks.hasSeen {
                showThanks = true
            } else {
                showPurchaseThanks = true
            }
        case .cancelled:
            break
        case .pending:
            alert = .pending
        case .unavailable:
            alert = .purchaseFailed("TapBTC Pro isn't available from the App Store right now. Check your connection and try again.")
        case .failed(let message):
            alert = .purchaseFailed(message.isEmpty
                                    ? "The purchase didn't go through. Check your connection and try again."
                                    : message)
        }
    }

    private func restorePurchases() async {
        restoring = true
        defer { restoring = false }
        switch await pro.restore() {
        case .restored:
            showThanks = true
        case .nothingToRestore:
            alert = .restoreEmpty
        case .failed(let message):
            alert = .restoreFailed(message.isEmpty
                                   ? "Couldn't reach the App Store to restore purchases."
                                   : message)
        }
    }

    private func retryAlert() {
        let retrying = alert
        alert = nil
        Task {
            switch retrying {
            case .purchaseFailed, .pending, .none:
                await buy()
            case .restoreEmpty, .restoreFailed:
                await restorePurchases()
            }
        }
    }
}

private struct ProFeature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
}

private enum PaywallAlert {
    case purchaseFailed(String)
    case pending
    case restoreEmpty
    case restoreFailed(String)

    var title: String {
        switch self {
        case .purchaseFailed: return "Purchase Failed"
        case .pending:        return "Waiting for Approval"
        case .restoreEmpty:   return "Nothing to Restore"
        case .restoreFailed:  return "Restore Failed"
        }
    }

    var message: String {
        switch self {
        case .purchaseFailed(let message):
            return message
        case .pending:
            return "Your purchase is pending. If Ask to Buy is on, a parent or guardian needs to approve it. TapBTC Pro unlocks as soon as it goes through."
        case .restoreEmpty:
            return "No TapBTC Pro purchase was found for this Apple ID."
        case .restoreFailed(let message):
            return message
        }
    }
}

enum StackPreviewFocus {
    case both
    case widget
    case watch
}

// Miniature My Stack widget + Watch row. Shared by the paywall hero, the
// post-holdings sheet, and the first-launch Pro walkthrough. Dollar amounts
// are only shown when we actually have them (or an explicit sample).
struct StackSurfacesPreview: View {
    var stackText: String?
    var gainPct: Double?
    var btcText: String?
    var showsBriefing: Bool = false
    var focus: StackPreviewFocus = .both
    var showsExampleLabel: Bool = false

    private let up = Color(red: 0.19, green: 0.82, blue: 0.35)
    private let down = Color(red: 1, green: 0.27, blue: 0.23)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(sectionTitle)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                if showsExampleLabel {
                    Text("EXAMPLE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                        .tracking(0.6)
                }
            }
            .padding(.horizontal, 4)

            surfaceCards

            if showsBriefing {
                briefingCard
            }
        }
        .padding(.horizontal, 20)
    }

    private var sectionTitle: String {
        switch focus {
        case .both: return "HOME SCREEN & WATCH"
        case .widget: return "MY STACK"
        case .watch: return "APPLE WATCH"
        }
    }

    @ViewBuilder
    private var surfaceCards: some View {
        switch focus {
        case .both:
            HStack(alignment: .top, spacing: 12) {
                widgetCard
                watchCard
            }
        case .widget:
            widgetCard
        case .watch:
            watchHero
        }
    }

    private var amountLine: String { stackText ?? "Your stack" }

    private var widgetCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("YOUR STACK")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
            }
            Text(amountLine)
                .font(.system(size: focus == .widget ? 28 : 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if let gainPct {
                Text("\(gainPct >= 0 ? "+" : "")\(String(format: "%.1f", gainPct * 100))% all-time")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(gainPct >= 0 ? up : down)
            } else if stackText == nil {
                Text("Live value & profit")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            if let btcText {
                Text("BTC \(btcText)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(previewBackground)
    }

    private var watchCard: some View {
        VStack(spacing: 5) {
            Text("WATCH")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(btcText ?? "BTC")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(stackText.map { "Stack · \($0)" } ?? "Your stack")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
                .minimumScaleFactor(0.55)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(width: 108, height: 118)
        .background(previewBackground)
    }

    private var watchHero: some View {
        VStack(spacing: 8) {
            Text("TAPBTC")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
            Text(btcText ?? "BTC")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(stackText.map { "Stack · \($0)" } ?? "Your stack")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let gainPct {
                Text("\(gainPct >= 0 ? "+" : "")\(String(format: "%.1f", gainPct * 100))% all-time")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(gainPct >= 0 ? up : down)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180)
        .background(previewBackground)
    }

    private var briefingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily briefing")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(briefingLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(previewBackground)
    }

    private var briefingLine: String {
        switch (btcText, stackText) {
        case let (btc?, stack?):
            return "BTC \(btc) · Stack \(stack)"
        case let (nil, stack?):
            return "Price, 24h move & your \(stack) stack"
        default:
            return "One morning push: price, 24h move & your stack"
        }
    }

    private var previewBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.14, green: 0.12, blue: 0.10),
                             Color(red: 0.07, green: 0.06, blue: 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// Full screen after the first holdings save: widget, Watch, and briefing,
// with a way through to Pro and an explicit Not now.
struct StackEverywhereView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pro = ProService.shared
    @State private var showPaywall = false

    private var stack: StackSnapshot { StackSnapshot.current }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.06, blue: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(.orange.opacity(0.15))
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(.orange)
                                }
                                Text("Put your stack everywhere")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 12)

                            StackSurfacesPreview(
                                stackText: stack.valueText,
                                gainPct: stack.gainPct,
                                btcText: stack.btcShort,
                                showsBriefing: true
                            )

                            VStack(spacing: 0) {
                                benefit("rectangle.on.rectangle", "Home Screen widget",
                                        "Live value and all-time profit on My Stack")
                                Divider().padding(.leading, 56)
                                benefit("applewatch", "Apple Watch",
                                        "Your stack on your wrist, next to the price")
                                Divider().padding(.leading, 56)
                                benefit("sun.max.fill", "Daily briefing",
                                        "One morning push: price, 24h move, and your stack")
                            }
                            .glassCard(cornerRadius: 18)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 8)
                        .readableWidth()
                    }

                    VStack(spacing: 12) {
                        Button { showPaywall = true } label: {
                            Text(unlockTitle)
                                .font(.system(.body, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                                .foregroundStyle(.black)
                        }
                        Button("Not now") { dismiss() }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .readableWidth()
                }
            }
            .adaptiveSheetSizing(.page)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall, onDismiss: {
                guard pro.isPro else { return }
                // Thank-you replaced the paywall. An animated dismiss of this
                // sheet would flash it after Done.
                var transaction = SwiftUI.Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { dismiss() }
            }) {
                PaywallView(trigger: .holdings)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var subtitle: String {
        if let value = stack.valueText {
            return "Your \(value) stack can live on your Home Screen, Watch, and in a morning briefing."
        }
        return "Pro shows the value you just saved on your Home Screen, Watch, and in a morning briefing."
    }

    private var unlockTitle: String {
        if let price = pro.displayPrice { return "Unlock Pro · \(price)" }
        return "Unlock Pro"
    }

    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
