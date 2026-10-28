import XCTest
import OvertimeCore

final class WorkweekDatesTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testSnapsToEmployerWeekday() {
        let wednesday = utc.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 15))!
        XCTAssertEqual(WorkweekDates.startOfWeek(containing: wednesday, weekday: 1, calendar: utc), day(2026, 10, 25))
        XCTAssertEqual(WorkweekDates.startOfWeek(containing: wednesday, weekday: 2, calendar: utc), day(2026, 10, 26))
        XCTAssertEqual(WorkweekDates.startOfWeek(containing: wednesday, weekday: 4, calendar: utc), day(2026, 10, 28))
    }

    func testTaxYearBoundsIncludeTheWeekThatHoldsJanuary1() {
        XCTAssertEqual(WorkweekDates.earliestStart(taxYear: 2026, weekday: 1, calendar: utc), day(2025, 12, 28))
        XCTAssertEqual(WorkweekDates.earliestStart(taxYear: 2026, weekday: 2, calendar: utc), day(2025, 12, 29))
        XCTAssertEqual(WorkweekDates.latestStart(taxYear: 2026, weekday: 1, calendar: utc), day(2026, 12, 27))
    }

    func testFreeTierWeekIsTheWeekContainingToday() {
        let now = day(2026, 10, 28)
        XCTAssertEqual(WorkweekDates.freeTierWeekStart(taxYear: 2026, weekday: 1, now: now, calendar: utc), day(2026, 10, 25))
    }

    func testFreeTierWeekClampsOutsideTheTaxYear() {
        XCTAssertEqual(
            WorkweekDates.freeTierWeekStart(taxYear: 2026, weekday: 1, now: day(2027, 3, 1), calendar: utc),
            day(2026, 12, 27)
        )
        XCTAssertEqual(
            WorkweekDates.freeTierWeekStart(taxYear: 2026, weekday: 1, now: day(2025, 6, 1), calendar: utc),
            day(2025, 12, 28)
        )
    }
}
