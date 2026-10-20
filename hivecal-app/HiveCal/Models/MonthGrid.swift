import Foundation

// Builds the 6x7 grid of dates for a given month, padded with adjacent-month
// days so every week row is complete.
struct MonthGrid {
    let monthDate: Date
    let weeks: [[Date]]

    init(monthDate: Date, calendar: Calendar = .current) {
        self.monthDate = monthDate
        var cal = calendar
        cal.firstWeekday = 1 // Sunday

        let range = cal.range(of: .day, in: .month, for: monthDate)!
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: monthDate))!
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let leadingBlank = (firstWeekday - cal.firstWeekday + 7) % 7

        var days: [Date] = []
        for i in stride(from: leadingBlank - 1, through: 0, by: -1) {
            days.append(cal.date(byAdding: .day, value: -(i + 1), to: firstOfMonth)!)
        }
        for d in 0..<range.count {
            days.append(cal.date(byAdding: .day, value: d, to: firstOfMonth)!)
        }
        while days.count % 7 != 0 || days.count < 42 {
            days.append(cal.date(byAdding: .day, value: 1, to: days.last!)!)
        }

        self.weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
    }
}
