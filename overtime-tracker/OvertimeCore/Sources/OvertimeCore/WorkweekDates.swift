import Foundation

/// FLSA workweek boundaries. Weekday numbers match `Calendar`: 1 = Sunday … 7 = Saturday.
public enum WorkweekDates {
    public static func normalizedWeekday(_ weekday: Int) -> Int {
        (1...7).contains(weekday) ? weekday : 1
    }

    /// Start of the employer's workweek that contains `date` (that day's start, in `calendar`).
    public static func startOfWeek(containing date: Date, weekday: Int, calendar: Calendar) -> Date {
        let weekday = normalizedWeekday(weekday)
        let day = calendar.startOfDay(for: date)
        let current = calendar.component(.weekday, from: day)
        let delta = (current - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: -delta, to: day) ?? day
    }

    /// Earliest week start that still overlaps `taxYear` (may fall in the prior December).
    public static func earliestStart(taxYear: Int, weekday: Int, calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.year = taxYear
        parts.month = 1
        parts.day = 1
        let jan1 = calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        return startOfWeek(containing: jan1, weekday: weekday, calendar: calendar)
    }

    /// Latest week start that still overlaps `taxYear`.
    public static func latestStart(taxYear: Int, weekday: Int, calendar: Calendar) -> Date {
        var parts = DateComponents()
        parts.year = taxYear
        parts.month = 12
        parts.day = 31
        let dec31 = calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        return startOfWeek(containing: dec31, weekday: weekday, calendar: calendar)
    }

    /// The one workweek the free tier can edit.
    ///
    /// When `now` falls inside the tax year, that is the workweek containing today.
    /// When `now` is outside the tax year, it is the earliest or latest workweek of that year,
    /// so the free tier still has one week to log.
    public static func freeTierWeekStart(taxYear: Int, weekday: Int, now: Date, calendar: Calendar) -> Date {
        let earliest = earliestStart(taxYear: taxYear, weekday: weekday, calendar: calendar)
        let latest = latestStart(taxYear: taxYear, weekday: weekday, calendar: calendar)
        let current = startOfWeek(containing: now, weekday: weekday, calendar: calendar)
        if current < earliest { return earliest }
        if current > latest { return latest }
        return current
    }

    public static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
