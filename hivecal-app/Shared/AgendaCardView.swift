import SwiftUI

// Mirrors the "Today / Tomorrow" widget layout Ryan liked — reused by both
// the in-app Today tab and the WidgetKit extension so they stay in sync.
struct AgendaCardView: View {
    let today: Date
    var showsCalendarStrip: Bool = true

    private var cal: Calendar { .current }
    private var tomorrow: Date { cal.date(byAdding: .day, value: 1, to: today)! }
    private var todayEvents: [CalendarEvent] { SampleData.events(on: today) }
    private var tomorrowEvents: [CalendarEvent] { SampleData.events(on: tomorrow) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(today, format: .dateTime.month(.wide))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(today, format: .dateTime.weekday(.wide))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.red)
                }
                Spacer()
                Text("\(cal.component(.day, from: today))")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Divider().background(Color.white.opacity(0.15))

            agendaSection(title: "TODAY", dateLabel: shortDate(today), events: todayEvents)
            agendaSection(title: "TOMORROW", dateLabel: shortDate(tomorrow), events: tomorrowEvents)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(red: 0.09, green: 0.09, blue: 0.1)))
    }

    private func agendaSection(title: String, dateLabel: String, events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(title == "TODAY" ? .blue : .white)
                Text(dateLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if events.isEmpty {
                Text("No events")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.prefix(4)) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(event.tag.color).frame(width: 7, height: 7).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            Text(event.startTimeText)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year(.twoDigits))
    }
}
