import SwiftData
import SwiftUI

struct RootView: View {
    @Query private var profiles: [TaxProfile]

    var body: some View {
        if profiles.contains(where: \.acceptedDisclaimer) {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}
