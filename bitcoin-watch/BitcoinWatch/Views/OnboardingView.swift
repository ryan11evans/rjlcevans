import SwiftUI

// Three-screen first-launch intro. The main job is asking for notification
// permission WITH context — a cold permission popup converts far worse than
// one that explains the closed-app alert system first.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @State private var notificationsEnabled = false

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
                welcome.tag(0)
                alerts.tag(1)
                done.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    // ── Page 1: Welcome ──────────────────────────────────────────────────────
    private var welcome: some View {
        pageLayout(
            art: {
                ZStack {
                    Circle().fill(.orange.opacity(0.15)).blur(radius: 30).frame(width: 160, height: 160)
                    Circle()
                        .fill(LinearGradient(colors: [
                            Color(red: 0.98, green: 0.70, blue: 0.28),
                            Color(red: 0.89, green: 0.50, blue: 0.04)
                        ], startPoint: .top, endPoint: .bottom))
                        .frame(width: 110, height: 110)
                    Text("₿")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.02))
                }
            },
            title: "Welcome to TapBTC",
            subtitle: "Live Bitcoin price, charts, stats and calculators.\nNo account. No ads. Just Bitcoin.",
            buttonTitle: "Continue",
            action: { withAnimation { page = 1 } }
        )
    }

    // ── Page 2: Alerts + permission ──────────────────────────────────────────
    private var alerts: some View {
        pageLayout(
            art: {
                ZStack {
                    Circle().fill(.orange.opacity(0.12)).blur(radius: 30).frame(width: 160, height: 160)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
            },
            title: "Alerts That Never Sleep",
            subtitle: "Set a price target and get a push the moment BTC crosses it — even when the app is closed.\nPlus new all-time highs and halving milestones, automatically.",
            buttonTitle: notificationsEnabled ? "Notifications On ✓" : "Enable Notifications",
            action: {
                Task {
                    notificationsEnabled = await PushService.shared.enable()
                    withAnimation { page = 2 }
                }
            },
            secondaryTitle: "Maybe Later",
            secondaryAction: { withAnimation { page = 2 } }
        )
    }

    // ── Page 3: Done ─────────────────────────────────────────────────────────
    private var done: some View {
        pageLayout(
            art: {
                ZStack {
                    Circle().fill(.green.opacity(0.12)).blur(radius: 30).frame(width: 160, height: 160)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                        .symbolRenderingMode(.hierarchical)
                }
            },
            title: "You're All Set",
            subtitle: notificationsEnabled
                ? "Price alerts, all-time high and halving notifications are live.\nTap the bell anytime to set your first target."
                : "You can enable notifications anytime from the bell icon.\nEverything else is ready to go.",
            buttonTitle: "Start Tracking",
            action: onFinish
        )
    }

    // ── Shared layout ────────────────────────────────────────────────────────
    @ViewBuilder
    private func pageLayout<Art: View>(
        @ViewBuilder art: () -> Art,
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()
            art()
                .frame(height: 180)
            Spacer().frame(height: 36)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Spacer().frame(height: 14)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
            Spacer()

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 24)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                Spacer().frame(height: 31)
            }

            Spacer().frame(height: 56)
        }
    }
}
