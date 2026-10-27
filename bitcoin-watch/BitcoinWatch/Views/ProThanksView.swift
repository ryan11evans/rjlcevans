import SwiftUI

// Shown once, inside the paywall sheet, after a successful purchase.
// Restore keeps the short "You're Pro" alert — re-confirming an old
// unlock shouldn't walk them through the widget again.
//
// Reset while debugging, then complete a new purchase (StoreKit Testing:
// Debug > StoreKit > Manage Transactions, delete the Pro transaction):
//   UserDefaults.standard.removeObject(forKey: "hasSeenProThanks")
enum ProPurchaseThanks {
    static let seenKey = "hasSeenProThanks"

    static var hasSeen: Bool { UserDefaults.standard.bool(forKey: seenKey) }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

struct ProThanksView: View {
    var onDone: () -> Void

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

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        StackSurfacesPreview(
                            stackText: preview.snapshot.valueText,
                            gainPct: preview.snapshot.gainPct,
                            btcText: preview.snapshot.btcShort,
                            focus: .widget,
                            showsExampleLabel: preview.isSample
                        )
                        steps
                        watchNote
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                    .readableWidth()
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(.body, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .readableWidth()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { ProPurchaseThanks.markSeen() }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.orange)
            }
            Text("You're Pro")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Thanks for supporting TapBTC. It's a one-time unlock — yours forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ADD MY STACK")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            step("1", "Touch and hold the Home Screen")
            step("2", "Tap the + button in the corner")
            step("3", "Search for TapBTC and choose My Stack")
            step("4", "Tap Add Widget")
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private var watchNote: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "applewatch")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("On Apple Watch now")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Your stack is on Apple Watch now. Open TapBTC on your wrist to see it next to the price.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 20)
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.orange))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
