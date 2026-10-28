import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            OvertimeTabView()
                .tabItem { Label("Overtime", systemImage: "clock") }

            CarLoanTabView()
                .tabItem { Label("Car Loan", systemImage: "car") }

            SummaryTabView()
                .tabItem { Label("Summary", systemImage: "list.bullet.rectangle") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
