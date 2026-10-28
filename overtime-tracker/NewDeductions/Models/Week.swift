import Foundation
import SwiftData

@Model
final class Week {
    var startDate: Date
    var hoursWorked: Decimal
    var hourlyRate: Decimal
    var includableExtras: Decimal
    var note: String?

    @Relationship(deleteRule: .cascade, inverse: \Shift.week)
    var shifts: [Shift]

    var employer: Employer?

    init(
        startDate: Date,
        hoursWorked: Decimal,
        hourlyRate: Decimal,
        includableExtras: Decimal = 0,
        note: String? = nil,
        employer: Employer? = nil
    ) {
        self.startDate = startDate
        self.hoursWorked = hoursWorked
        self.hourlyRate = hourlyRate
        self.includableExtras = includableExtras
        self.note = note
        self.shifts = []
        self.employer = employer
    }
}
