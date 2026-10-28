import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            OvertimeTabView()
                .tabItem { Label("Overtime", systemImage: "clock.fill") }

            CarLoanTabView()
                .tabItem { Label("Car Loan", systemImage: "car.fill") }

            SummaryTabView()
                .tabItem { Label("Summary", systemImage: "chart.pie.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.emerald)
    }
}
