import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PlaceholderTabView(
                title: "Overtime",
                systemImage: "clock",
                message: "The year dial and week log are not in this version yet."
            )
            .tabItem { Label("Overtime", systemImage: "clock") }

            PlaceholderTabView(
                title: "Car Loan",
                systemImage: "car",
                message: "VIN eligibility and the interest estimate are not in this version yet. Nothing is sent off this device."
            )
            .tabItem { Label("Car Loan", systemImage: "car") }

            PlaceholderTabView(
                title: "Summary",
                systemImage: "list.bullet.rectangle",
                message: "The combined Schedule 1-A summary is not in this version yet."
            )
            .tabItem { Label("Summary", systemImage: "list.bullet.rectangle") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
