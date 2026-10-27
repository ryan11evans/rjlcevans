import SwiftUI

// First-launch Pro walkthrough. New installs only — `shouldOffer` marks
// upgrades as seen so people who already opened the app, or who already
// hold bitcoin, never see it.
//
// Reset while debugging (then relaunch):
//   UserDefaults.standard.set(true, forKey: "proWalkthroughPending")
//   UserDefaults.standard.removeObject(forKey: "hasSeenProWalkthrough")
// Setting the pending flag is what forces it on an install that has already
// been opened. Deleting the seen flag alone is not enough.
enum ProWalkthrough {
    static let seenKey = "hasSeenProWalkthrough"
    static let pendingKey = "proWalkthroughPending"

    /// True while this launch owes the user the walkthrough. Stack-everywhere
    /// stays quiet until the cover dismisses.
    static var suppressOtherPrompts = false

    static var hasSeen: Bool { UserDefaults.standard.bool(forKey: seenKey) }

    static func markSeen() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: seenKey)
        defaults.set(false, forKey: pendingKey)
    }

    /// Call once at launch, before the open count increments.
    static func shouldOffer() -> Bool {
        if hasSeen { return false }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: pendingKey) {
            suppressOtherPrompts = true
            return true
        }
        let openedBefore = defaults.integer(forKey: "appOpenCount") > 0
            || UserDefaults.shared.bool(forKey: "hasSeenOnboarding")
        let hasHoldings = UserDefaults.shared.double(forKey: "btcHoldings") > 0
        let alreadyPro = UserDefaults.shared.bool(forKey: "isProUnlocked")
        if openedBefore || hasHoldings || alreadyPro {
            markSeen()
            return false
        }
        defaults.set(true, forKey: pendingKey)
        suppressOtherPrompts = true
        return true
    }
}

struct ProOnboardingView: View {
    var onGetPro: () -> Void
    var onFinish: () -> Void

    @State private var page = 0

    private var preview: (snapshot: StackSnapshot, isSample: Bool) {
        StackSnapshot.liveOrSample()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                         Color(red: 0.07, green: 0.06, blue: 0.06),
                         Color(red: 0.02, green: 0.02, blue: 0.02)],
                startPoint: .topLeading, endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $page) {
                widgetPage.tag(0)
                watchPage.tag(1)
                offerPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .opacity(page < 2 ? 1 : 0)
                        .disabled(page >= 2)
                        .accessibilityHidden(page >= 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var widgetPage: some View {
        pageLayout(
            title: "Your stack on the Home Screen",
            subtitle: "Pro adds My Stack, a widget with the live value of your bitcoin and your all-time profit.",
            buttonTitle: "Next",
            action: { withAnimation { page = 1 } }
        ) {
            StackSurfacesPreview(
                stackText: preview.snapshot.valueText,
                gainPct: preview.snapshot.gainPct,
                btcText: preview.snapshot.btcShort,
                focus: .widget,
                showsExampleLabel: preview.isSample
            )
        }
    }

    private var watchPage: some View {
        pageLayout(
            title: "And on Apple Watch",
            subtitle: "The same stack sits on your wrist, right next to the Bitcoin price.",
            buttonTitle: "Next",
            action: { withAnimation { page = 2 } }
        ) {
            StackSurfacesPreview(
                stackText: preview.snapshot.valueText,
                gainPct: preview.snapshot.gainPct,
                btcText: preview.snapshot.btcShort,
                focus: .watch,
                showsExampleLabel: preview.isSample
            )
        }
    }

    private var offerPage: some View {
        pageLayout(
            title: "Free, with optional Pro",
            subtitle: "TapBTC is free. Pro is an optional one-time unlock — no subscription — that puts your stack on the Home Screen and Apple Watch.",
            buttonTitle: "Get Pro",
            action: onGetPro,
            secondaryTitle: "Continue free",
            secondaryAction: onFinish
        ) {
            ZStack {
                Circle().fill(.orange.opacity(0.15)).blur(radius: 30).frame(width: 160, height: 160)
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
        }
    }

    private func pageLayout<Art: View>(
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        @ViewBuilder art: () -> Art
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer().frame(height: 12)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
            Spacer().frame(height: 22)
            art()
            Spacer()

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(.body, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                Spacer().frame(height: 44)
            }

            Spacer().frame(height: 56)
        }
        .readableWidth(560)
    }
}
