import Foundation

// Placeholder data so the UI can be evaluated before real calendar sync is wired up.
enum SampleData {
    static let events: [CalendarEvent] = buildEvents()

    private static func buildEvents() -> [CalendarEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
        func at(_ base: Date, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
        }
        func ev(_ title: String, _ offset: Int, _ startHour: Int?, _ endHour: Int? = nil,
                tag: EventTag, location: String? = nil) -> CalendarEvent {
            let base = day(offset)
            guard let startHour else {
                return CalendarEvent(title: title, start: base, end: base, isAllDay: true, tag: tag, location: location)
            }
            let start = at(base, startHour)
            let end = at(base, endHour ?? (startHour + 1))
            return CalendarEvent(title: title, start: start, end: end, isAllDay: false, tag: tag, location: location)
        }

        var events: [CalendarEvent] = []
        events.append(ev("Landon's Baseball Practice", 0, 17, 18, tag: .sports, location: "Murrieta Sports Park"))
        events.append(ev("Jadyn – Work", 0, 8, 17, tag: .work))
        events.append(ev("Opening Day", 1, 9, 12, tag: .sports, location: "37000 Ruth Ellen Dr, Murrieta"))
        events.append(ev("Landon – Orthodontist", 1, nil, tag: .medical))
        events.append(ev("Jadyn – Work", 1, 8, 17, tag: .work))
        events.append(ev("Book Club", 2, 19, 21, tag: .personal))
        events.append(ev("Cody's Dentist Appointment", 3, 14, 15, tag: .medical))
        events.append(ev("On Call – Ryan", 4, nil, tag: .work))
        events.append(ev("Date Night", 4, 18, 21, tag: .personal))
        events.append(ev("Baseball Game vs. Hawks", 5, 9, 11, tag: .sports, location: "Field 3"))
        events.append(ev("Rosh Hashanah", 5, nil, tag: .holiday))
        events.append(ev("Family Movie Night", 6, 19, 21, tag: .family))
        events.append(ev("Umpire Clinic", 6, 8, 12, tag: .sports))
        events.append(ev("Jadyn – Work", 7, 8, 17, tag: .work))
        events.append(ev("Landon – Orthodontist Follow-up", 7, 10, 11, tag: .medical))
        events.append(ev("Book Fair", 8, nil, tag: .personal))
        events.append(ev("Chick-Fil-A Family Night", 8, 17, 19, tag: .family))
        events.append(ev("Yom Kippur", 9, nil, tag: .holiday))
        events.append(ev("New Optometry Patients Open House", 10, 9, 13, tag: .work, location: "Practice Office"))
        events.append(ev("Landon – Appointment", 10, 15, 16, tag: .medical))
        events.append(ev("Cody's Piano Lesson", 11, 16, 17, tag: .personal))
        events.append(ev("House Cleaning", 12, nil, tag: .personal))
        events.append(ev("Massage – Jadyn", 13, 11, 12, tag: .personal))
        events.append(ev("Paint & Sip Night", 13, 18, 20, tag: .family))
        events.append(ev("Landon's Baseball – Home Opener", -1, 9, 11, tag: .sports))
        events.append(ev("Surgery Day – Clinic Closed", -3, nil, tag: .medical))
        events.append(ev("Trip to Meet Enya", -9, nil, tag: .family))
        return events
    }

    static func events(on date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.isAllDay && !$1.isAllDay ? true : $0.start < $1.start }
    }
}
