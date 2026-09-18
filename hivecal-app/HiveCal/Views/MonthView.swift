import SwiftUI

struct MonthView: View {
    @State private var monthDate: Date = Date()
    @State private var selectedDay: Date?
    @State private var layout: CalendarLayout = .month

    private let cal = Calendar.current
    private let weekdaySymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    enum CalendarLayout: String, CaseIterable {
        case month = "Month"
        case list = "List"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            layoutPicker
            if layout == .month {
                weekdayRow
                monthGrid
            } else {
                AgendaListView(anchorDate: Date())
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: Binding(
            get: { selectedDay.map { IdentifiableDate(date: $0) } },
            set: { selectedDay = $0?.date }
        )) { wrapped in
            DayDetailSheet(date: wrapped.date)
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Text(monthDate, format: .dateTime.month(.wide))
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            Text(monthDate, format: .dateTime.year())
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.red)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").foregroundStyle(.white)
            }
            Button { monthDate = Date() } label: {
                Text("Today").font(.system(size: 13, weight: .semibold))
            }
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var layoutPicker: some View {
        Picker("Layout", selection: $layout) {
            ForEach(CalendarLayout.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }

    private var monthGrid: some View {
        let grid = MonthGrid(monthDate: monthDate, calendar: cal)
        return GeometryReader { geo in
            let rowHeight = geo.size.height / CGFloat(grid.weeks.count)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(grid.weeks.indices, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(grid.weeks[row], id: \.self) { date in
                                DayCell(
                                    date: date,
                                    isCurrentMonth: cal.isDate(date, equalTo: monthDate, toGranularity: .month),
                                    isToday: cal.isDateInToday(date),
                                    events: SampleData.events(on: date)
                                )
                                .frame(height: max(rowHeight, 108))
                                .frame(maxWidth: .infinity)
                                .onTapGesture { selectedDay = date }
                            }
                        }
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        monthDate = cal.date(byAdding: .month, value: delta, to: monthDate) ?? monthDate
    }
}

private struct IdentifiableDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct DayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let events: [CalendarEvent]

    private let maxVisible = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            dayNumber
            ForEach(events.prefix(maxVisible)) { event in
                EventChip(event: event, compact: true)
            }
            if events.count > maxVisible {
                MoreEventsPill(count: events.count - maxVisible)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .background(isToday ? Color.blue.opacity(0.16) : Color.clear)
        .overlay(Rectangle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        .opacity(isCurrentMonth ? 1 : 0.35)
    }

    private var dayNumber: some View {
        Text("\(Calendar.current.component(.day, from: date))")
            .font(.system(size: 13, weight: isToday ? .bold : .regular))
            .foregroundStyle(isToday ? .blue : .white)
            .padding(.horizontal, isToday ? 6 : 0)
            .padding(.vertical, isToday ? 2 : 0)
            .background(isToday ? Capsule().fill(Color.blue.opacity(0.25)) : nil)
    }
}
