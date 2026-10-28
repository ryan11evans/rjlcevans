import XCTest
import OvertimeCore

final class Schedule1ACalculatorTests: XCTestCase {
    private func money(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testCombinedDeductionAndTaxSaved() {
        let estimate = Schedule1ACalculator.estimate(
            overtimeDeduction: 5_300,
            carLoanDeduction: 1_300,
            marginalRate: money("0.22")
        )
        XCTAssertEqual(estimate.combinedDeduction, 6_600)
        XCTAssertEqual(estimate.estimatedTaxSaved, 1_452)
    }

    func testW4Line4bIsTheSumOfTheTwoDeductions() {
        XCTAssertEqual(Schedule1ACalculator.suggestedW4Line4b(overtimeDeduction: 5_300, carLoanDeduction: 1_300), 6_600)
        XCTAssertEqual(Schedule1ACalculator.suggestedW4Line4b(overtimeDeduction: 0, carLoanDeduction: 800), 800)
    }

    func testCodeTTDifference() {
        let higher = Schedule1ACalculator.compareCodeTT(reported: 1_800, computedPremium: 1_500)
        XCTAssertEqual(higher.reportedMinusComputed, 300)
        let lower = Schedule1ACalculator.compareCodeTT(reported: 1_000, computedPremium: 1_500)
        XCTAssertEqual(lower.reportedMinusComputed, -500)
        let same = Schedule1ACalculator.compareCodeTT(reported: money("150.00"), computedPremium: 150)
        XCTAssertEqual(same.reportedMinusComputed, 0)
    }
}
