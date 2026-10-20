import SwiftUI

// Full-text event list for a single day — the "read all the events easier"
// escape hatch when a day's chips are truncated in the month grid.
struct DayDetailSheet: View {
    let date: Date

    private var events: [CalendarEvent] { SampleData.events(on: date) }

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    Text("No events").foregroundStyle(.secondary)
                } else {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.tag.color)
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(event.timeRangeText)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                if let location = event.location {
                                    Label(location, systemImage: "mappin.and.ellipse")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
