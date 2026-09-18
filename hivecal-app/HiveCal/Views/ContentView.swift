import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MonthView()
                .tabItem { Label("Month", systemImage: "calendar") }
            AgendaTabView()
                .tabItem { Label("Today", systemImage: "list.bullet.rectangle") }
        }
        .preferredColorScheme(.dark)
        .tint(.blue)
    }
}

private struct AgendaTabView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                AgendaCardView(today: Date())
                    .padding(16)
            }
        }
    }
}

#Preview {
    ContentView()
}
