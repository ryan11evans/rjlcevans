import SwiftUI

// Full-width day-by-day list: every event title reads in full, no truncation,
// trading the month-grid's at-a-glance layout for guaranteed legibility.
struct AgendaListView: View {
    let anchorDate: Date
    var daySpan: Int = 21 // ~3 weeks

    private var cal: Calendar { .current }
    private var days: [Date] {
        let start = cal.startOfDay(for: anchorDate)
        return (0..<daySpan).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                let events = SampleData.events(on: day)
                Section {
                    if events.isEmpty {
                        Text("No events")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { event in
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(event.tag.color)
                                    .frame(width: 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                    HStack(spacing: 6) {
                                        Text(event.timeRangeText)
                                        if let location = event.location {
                                            Text("·")
                                            Text(location)
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                } header: {
                    HStack {
                        Text(day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(cal.isDateInToday(day) ? .blue : .secondary)
                        if cal.isDateInToday(day) {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.25)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }
}
