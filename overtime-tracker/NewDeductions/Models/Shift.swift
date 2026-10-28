import Foundation
import SwiftData

@Model
final class Shift {
    var clockIn: Date
    var clockOut: Date?
    var week: Week?

    init(clockIn: Date, clockOut: Date? = nil, week: Week? = nil) {
        self.clockIn = clockIn
        self.clockOut = clockOut
        self.week = week
    }
}
