import SwiftUI

enum EventTag: String, CaseIterable {
    case work, family, sports, medical, personal, holiday

    var color: Color {
        switch self {
        case .work:     return Color(red: 0.98, green: 0.58, blue: 0.20) // orange
        case .family:   return Color(red: 0.98, green: 0.42, blue: 0.62) // pink
        case .sports:   return Color(red: 0.23, green: 0.68, blue: 0.98) // blue
        case .medical:  return Color(red: 0.35, green: 0.78, blue: 0.55) // green
        case .personal: return Color(red: 0.65, green: 0.55, blue: 0.98) // purple
        case .holiday:  return Color(red: 0.90, green: 0.30, blue: 0.30) // red
        }
    }
}

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let tag: EventTag
    let location: String?

    var timeRangeText: String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    var startTimeText: String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: start)
    }
}
