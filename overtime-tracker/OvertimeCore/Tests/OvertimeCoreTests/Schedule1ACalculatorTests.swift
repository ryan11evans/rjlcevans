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

    func testLine4bAppliesOvertimeAndCarLoanCaps() {
        let capped = Schedule1ACalculator.line4bAmount(
            projectedQualifiedPremium: 20_000,
            carLoanInterest: 1_200,
            filingStatus: .single,
            magi: 90_000,
            taxYear: 2026
        )
        XCTAssertEqual(capped, 13_700)

        let phased = Schedule1ACalculator.line4bAmount(
            projectedQualifiedPremium: 15_000,
            carLoanInterest: 10_000,
            filingStatus: .single,
            magi: 175_000,
            taxYear: 2026
        )
        // Overtime: 12,500 cap, then $2,500 phase-out → 10,000.
        // Car interest is fully phased out at this MAGI.
        XCTAssertEqual(phased, 10_000)

        let noCar = Schedule1ACalculator.line4bAmount(
            projectedQualifiedPremium: 5_300,
            carLoanInterest: 0,
            filingStatus: .single,
            magi: 90_000,
            taxYear: 2026
        )
        XCTAssertEqual(noCar, 5_300)
    }

    func testLine4bDropsOvertimeWhenIneligible() {
        XCTAssertEqual(
            Schedule1ACalculator.line4bAmount(
                projectedQualifiedPremium: 5_000,
                carLoanInterest: 100,
                filingStatus: .marriedFilingSeparately,
                magi: 40_000,
                taxYear: 2026
            ),
            100
        )
        XCTAssertEqual(
            Schedule1ACalculator.line4bAmount(
                projectedQualifiedPremium: 5_000,
                carLoanInterest: 0,
                filingStatus: .single,
                magi: 40_000,
                hasValidSSN: false,
                taxYear: 2026
            ),
            0
        )
        XCTAssertEqual(
            Schedule1ACalculator.line4bAmount(
                projectedQualifiedPremium: 0,
                carLoanInterest: 800,
                filingStatus: .single,
                magi: 40_000,
                taxYear: 2024
            ),
            0
        )
    }

    func testCodeTTComparisonVerdicts() {
        XCTAssertEqual(Schedule1ACalculator.comparison(reported: nil, computedPremium: 1_500), .notOnW2)
        XCTAssertNil(Schedule1ACalculator.comparison(reported: nil, computedPremium: 0).reportedMinusLog)

        let match = Schedule1ACalculator.comparison(reported: money("150.00"), computedPremium: 150)
        XCTAssertEqual(match, .match)
        XCTAssertEqual(match.reportedMinusLog, 0)

        let cents = Schedule1ACalculator.comparison(reported: money("150.004"), computedPremium: 150)
        XCTAssertEqual(cents, .match)

        let short = Schedule1ACalculator.comparison(reported: 1_000, computedPremium: 1_500)
        XCTAssertEqual(short, .possibleShortfall(dollars: 500))
        XCTAssertEqual(short.reportedMinusLog, -500)

        let over = Schedule1ACalculator.comparison(reported: 1_800, computedPremium: 1_500)
        XCTAssertEqual(over, .overage(dollars: 300))
        XCTAssertEqual(over.reportedMinusLog, 300)

        let penny = Schedule1ACalculator.comparison(reported: 10, computedPremium: money("10.006"))
        XCTAssertEqual(penny, .possibleShortfall(dollars: money("0.01")))
    }
}
