import SwiftData
import SwiftUI

struct RootView: View {
    @Query private var profiles: [TaxProfile]

    var body: some View {
        Group {
            if profiles.contains(where: \.acceptedDisclaimer) {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.emerald)
        .fontDesign(.rounded)
        .background(Theme.background.ignoresSafeArea())
    }
}
