import WidgetKit
import SwiftUI

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry { AgendaEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
        completion(AgendaEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        completion(Timeline(entries: [AgendaEntry(date: Date())], policy: .after(midnight)))
    }
}

struct AgendaEntry: TimelineEntry {
    let date: Date
}

struct HiveCalWidgetView: View {
    let entry: AgendaEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            AgendaCardView(today: entry.date)
                .containerBackground(for: .widget) { Color(red: 0.09, green: 0.09, blue: 0.1) }
        default:
            AgendaCardView(today: entry.date)
                .containerBackground(for: .widget) { Color(red: 0.09, green: 0.09, blue: 0.1) }
        }
    }
}

struct HiveCalAgendaWidget: Widget {
    let kind = "HiveCalAgendaWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AgendaProvider()) { entry in
            HiveCalWidgetView(entry: entry)
        }
        .configurationDisplayName("Today & Tomorrow")
        .description("Your next two days at a glance, fully readable.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct HiveCalWidgetBundle: WidgetBundle {
    var body: some Widget {
        HiveCalAgendaWidget()
    }
}
