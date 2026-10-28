import Foundation
import XCTest
import OvertimeCore

/// Expected values cross-checked in Python (Decimal, cents rounding) — see PLAN.md §7.
final class CarLoanInterestCalculatorTests: XCTestCase {
    typealias C = CarLoanInterestCalculator
    func d(_ y: Int, _ m: Int, _ dd: Int) -> Date { C.utc.date(from: DateComponents(year: y, month: m, day: dd))! }

    /// Expected money literals are dot-decimal. `Decimal(string:)` is optional and locale-sensitive;
    /// this pins `en_US_POSIX` so the assertions type-check and keep the same expected numbers.
    private func money(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testPaymentAndYearlyInterest_40k_6pct_60mo() {
        XCTAssertEqual(C.monthlyPayment(principal: 40_000, aprPercent: 6, months: 60), money("773.31"))
        XCTAssertEqual(C.projectedInterest(principal: 40_000, aprPercent: 6, months: 60, firstPaymentYear: 2026, firstPaymentMonth: 2, taxYear: 2026), money("2039.94"))
        XCTAssertEqual(C.projectedInterest(principal: 40_000, aprPercent: 6, months: 60, firstPaymentYear: 2026, firstPaymentMonth: 2, taxYear: 2027), money("1808.78"))
    }
    func testZeroAPR() {
        XCTAssertEqual(C.projectedInterest(principal: 30_000, aprPercent: 0, months: 36, firstPaymentYear: 2025, firstPaymentMonth: 6, taxYear: 2025), 0)
    }
    func testBigLoanHitsCap() {
        XCTAssertEqual(C.projectedInterest(principal: 150_000, aprPercent: 9, months: 72, firstPaymentYear: 2025, firstPaymentMonth: 1, taxYear: 2025), money("12698.62"))
        XCTAssertEqual(C.deduction(interest: 12_000, magi: 90_000, status: .single, taxYear: 2025), 10_000)
    }
    func testPhaseOutRoundsPartialThousandUp() {
        XCTAssertEqual(C.deduction(interest: 2_300, magi: 104_200, status: .single, taxYear: 2026), 1_300) // 5 steps
        XCTAssertEqual(C.deduction(interest: 2_300, magi: 104_001, status: .single, taxYear: 2026), 1_300)
        XCTAssertEqual(C.deduction(interest: 9_500, magi: 205_000, status: .marriedFilingJointly, taxYear: 2026), 8_500)
        XCTAssertEqual(C.deduction(interest: 5_000, magi: 149_500, status: .single, taxYear: 2026), 0)
    }
    func testOutsideYears() { XCTAssertEqual(C.deduction(interest: 5_000, magi: 50_000, status: .single, taxYear: 2029), 0) }

    func testCapAppliesToTheSumOfQualifyingLoans() {
        XCTAssertEqual(C.deduction(loanInterest: [6_000, 6_000], magi: 90_000, status: .single, taxYear: 2026), 10_000)
        // Same MAGI as the partial-thousand test: 5 steps × $200, taken off the $10,000 cap.
        XCTAssertEqual(C.deduction(loanInterest: [6_000, 6_000], magi: 104_200, status: .single, taxYear: 2026), 9_000)
    }

    func testVerdicts() {
        let ok = VehicleLoanFacts(originationDate: d(2026, 3, 1), isNew: true, personalUse: true, firstLien: true,
                                  vehicleType: .pickup, gvwrPounds: 7_500, assembly: .usPlant)
        XCTAssertEqual(C.verdict(ok), .eligible)
        var f = ok; f.originationDate = d(2024, 12, 31); XCTAssertEqual(C.verdict(f), .notEligible)
        f = ok; f.assembly = .nonUSPlant; XCTAssertEqual(C.verdict(f), .notEligible)
        f = ok; f.assembly = .unknown; XCTAssertEqual(C.verdict(f), .checkSticker)
        f = ok; f.firstLien = nil; XCTAssertEqual(C.verdict(f), .likely)
        f = ok; f.gvwrPounds = 14_000; XCTAssertEqual(C.verdict(f), .notEligible)
        f = ok; f.isLease = true; XCTAssertEqual(C.verdict(f), .notEligible)
        f = ok; f.isNew = false; XCTAssertEqual(C.verdict(f), .notEligible)
    }
}
