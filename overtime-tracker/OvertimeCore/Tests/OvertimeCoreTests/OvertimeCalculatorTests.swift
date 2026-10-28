import Foundation
import XCTest
import OvertimeCore

final class OvertimeCalculatorTests: XCTestCase {

    /// Expected money literals are dot-decimal. Pin the locale so a comma-separator Mac still compiles and matches.
    private func money(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testBriefExample_30perHour_10OTHours() {
        // $30/hr, 50 hours worked -> 10 OT hrs. Premium = 10 x 30 x 0.5 = $150.
        let r = OvertimeCalculator.compute(WorkWeek(hoursWorked: 50, hourlyRate: 30))
        XCTAssertEqual(r.overtimeHours, 10)
        XCTAssertEqual(r.qualifiedPremium, 150)
        XCTAssertEqual(r.totalOvertimePay, 450)
    }

    func testNoOvertimeAtOrUnder40() {
        XCTAssertEqual(OvertimeCalculator.compute(WorkWeek(hoursWorked: 40, hourlyRate: 30)).qualifiedPremium, 0)
        XCTAssertEqual(OvertimeCalculator.compute(WorkWeek(hoursWorked: 32, hourlyRate: 30)).qualifiedPremium, 0)
    }

    func testRegularRateIncludesShiftDifferential() {
        // 45 hrs x $20 + $90 night differential -> RR = (900+90)/45 = $22. Premium = 5 x 22 x 0.5 = $55.
        let r = OvertimeCalculator.compute(WorkWeek(hoursWorked: 45, hourlyRate: 20, includableExtras: 90))
        XCTAssertEqual(r.regularRate, 22)
        XCTAssertEqual(r.qualifiedPremium, 55)
    }

    func testAnnualCapSingle() {
        // $150/wk x 50 wks = $7,500 -> under cap.
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 7_500, filingStatus: .single, magi: 90_000), 7_500)
        // $20,000 premium single -> capped at $12,500.
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 20_000, filingStatus: .single, magi: 120_000), 12_500)
    }

    func testCapJoint() {
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 30_000, filingStatus: .marriedFilingJointly, magi: 200_000), 25_000)
    }

    func testPhaseOutSingle() {
        // MAGI $175,000 -> $25,000 over -> 25 x $100 = $2,500 reduction. 12,500 - 2,500 = 10,000.
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 15_000, filingStatus: .single, magi: 175_000), 10_000)
        // Fully phased out at $275,000.
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 15_000, filingStatus: .single, magi: 275_000), 0)
    }

    func testPhaseOutJoint() {
        // MAGI $310,500 MFJ -> 10 whole $1,000 steps -> $1,000 reduction.
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 8_000, filingStatus: .marriedFilingJointly, magi: 310_500), 7_000)
    }

    func testIneligibleCases() {
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 5_000, filingStatus: .marriedFilingSeparately, magi: 60_000), 0)
        XCTAssertEqual(OvertimeCalculator.deduction(qualifiedOvertime: 5_000, filingStatus: .single, magi: 60_000, hasValidSSN: false), 0)
    }

    func testTaxSavingsEstimate() {
        XCTAssertEqual(OvertimeCalculator.estimatedTaxSavings(deduction: 7_500, marginalRate: money("0.22")), 1_650)
    }

    func testQuarterHoursAndExtras() {
        // 42.5 hrs × $20 + $85 extras → RR = (850+85)/42.5 = $22. OT = 2.5. Premium = 2.5 × 22 × 0.5 = $27.50.
        let week = WorkWeek(hoursWorked: money("42.5"), hourlyRate: 20, includableExtras: 85)
        let result = OvertimeCalculator.compute(week)
        XCTAssertEqual(result.regularRate, 22)
        XCTAssertEqual(result.overtimeHours, money("2.5"))
        XCTAssertEqual(result.qualifiedPremium, money("27.50"))
        XCTAssertEqual(OvertimeCalculator.regularRate(for: week), 22)
    }

    func testProjectedYearEndPremiumIsAverageTimes52() {
        // 10 logged weeks, $1,500 year to date → $150 average × 52 = $7,800.
        XCTAssertEqual(OvertimeCalculator.projectedYearEndPremium(ytdQualifiedPremium: 1_500, weeksLogged: 10), 7_800)
        XCTAssertEqual(OvertimeCalculator.projectedYearEndPremium(ytdQualifiedPremium: 100, weeksLogged: 3), money("1733.33"))
        XCTAssertEqual(OvertimeCalculator.projectedYearEndPremium(ytdQualifiedPremium: 0, weeksLogged: 0), 0)
    }

    func testPhaseOutAppliesToProjectedPremium() {
        let weeks = Array(repeating: WorkWeek(hoursWorked: 50, hourlyRate: 30), count: 10)
        let estimate = OvertimeCalculator.yearEstimate(
            weeks: weeks,
            filingStatus: .single,
            magi: 175_000,
            marginalRate: money("0.22")
        )
        XCTAssertEqual(estimate.ytdQualifiedPremium, 1_500)
        XCTAssertEqual(estimate.projectedYearEndPremium, 7_800)
        // $25,000 over the single threshold → 25 × $100 = $2,500 off $7,800.
        XCTAssertEqual(estimate.estimatedDeduction, 5_300)
        XCTAssertEqual(estimate.estimatedTaxSaved, 1_166)
    }

    func testProjectedPremiumMarriedFilingSeparatelyIsZero() {
        let weeks = Array(repeating: WorkWeek(hoursWorked: 50, hourlyRate: 30), count: 10)
        let estimate = OvertimeCalculator.yearEstimate(
            weeks: weeks,
            filingStatus: .marriedFilingSeparately,
            magi: 60_000,
            marginalRate: money("0.22")
        )
        XCTAssertEqual(estimate.projectedYearEndPremium, 7_800)
        XCTAssertEqual(estimate.estimatedDeduction, 0)
        XCTAssertEqual(estimate.estimatedTaxSaved, 0)
    }

    func testYearEstimateWithNoWeeks() {
        let estimate = OvertimeCalculator.yearEstimate(weeks: [], filingStatus: .single, magi: 90_000, marginalRate: money("0.24"))
        XCTAssertEqual(estimate.weeksLogged, 0)
        XCTAssertEqual(estimate.ytdQualifiedPremium, 0)
        XCTAssertEqual(estimate.projectedYearEndPremium, 0)
        XCTAssertEqual(estimate.estimatedDeduction, 0)
        XCTAssertEqual(estimate.estimatedTaxSaved, 0)
    }
}
