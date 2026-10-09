import SwiftUI

// Full-screen cover shown when the app is locked. Also serves as the privacy
// screen so holdings aren't visible in the app switcher.
struct LockView: View {
    @ObservedObject private var lock = AppLockService.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.11, blue: 0.10),
                         Color(red: 0.05, green: 0.04, blue: 0.04)],
                startPoint: .topLeading, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(.orange.opacity(0.15)).frame(width: 110, height: 110)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(spacing: 6) {
                    Text("TapBTC is Locked")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Authenticate to view your Bitcoin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let authError = lock.authError {
                        Text(authError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Button {
                    lock.authenticate()
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .font(.system(.callout, weight: .bold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
                        .foregroundStyle(.black)
                }
            }
        }
        .onAppear { lock.authenticate() }
    }
}
