import XCTest
import OvertimeCore

final class PaycheckCalculatorTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func money(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testPeriodsPerYear() {
        XCTAssertEqual(PayFrequency.weekly.periodsPerYear, 52)
        XCTAssertEqual(PayFrequency.biweekly.periodsPerYear, 26)
        XCTAssertEqual(PayFrequency.semimonthly.periodsPerYear, 24)
        XCTAssertEqual(PayFrequency.monthly.periodsPerYear, 12)
        XCTAssertEqual(PayFrequency.biweekly.rawValue, "biweekly")
    }

    func testRemainingPaychecksAtTheStartOf2026() {
        let jan1 = date(2026, 1, 1)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: jan1, calendar: utc), 52)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: jan1, calendar: utc), 26)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: jan1, calendar: utc), 24)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: jan1, calendar: utc), 12)
    }

    func testRemainingPaychecksCountsAPaydayThatIsToday() {
        let jan2 = date(2026, 1, 2) // first Friday, and a biweekly payday
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: jan2, calendar: utc), 52)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: jan2, calendar: utc), 26)

        let jan16 = date(2026, 1, 16) // Friday, second biweekly payday
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: jan16, calendar: utc), 50)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: jan16, calendar: utc), 25)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: jan16, calendar: utc), 23)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: jan16, calendar: utc), 12)
    }

    func testRemainingPaychecksMidYearAndYearEndFloor() {
        let june15 = date(2026, 6, 15)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: june15, calendar: utc), 28)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: june15, calendar: utc), 14)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: june15, calendar: utc), 14)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: june15, calendar: utc), 7)

        let june16 = date(2026, 6, 16)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: june16, calendar: utc), 13)

        let feb28 = date(2026, 2, 28)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: feb28, calendar: utc), 43)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: feb28, calendar: utc), 21)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: feb28, calendar: utc), 21)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: feb28, calendar: utc), 11)

        let oct29 = date(2026, 10, 29)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: oct29, calendar: utc), 9)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: oct29, calendar: utc), 4)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: oct29, calendar: utc), 5)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: oct29, calendar: utc), 3)

        // Dec 31, 2026 is a Thursday. The last Friday was Dec 25, so weekly and biweekly
        // have no payday left. The result stays 1 so the per-paycheck split can divide.
        let dec31 = date(2026, 12, 31)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: dec31, calendar: utc), 1)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: dec31, calendar: utc), 1)
        XCTAssertEqual(PayFrequency.semimonthly.remainingPaychecks(on: dec31, calendar: utc), 1)
        XCTAssertEqual(PayFrequency.monthly.remainingPaychecks(on: dec31, calendar: utc), 1)
    }

    func test2025AlsoStartsWith52Fridays() {
        let jan1 = date(2025, 1, 1)
        XCTAssertEqual(PayFrequency.weekly.remainingPaychecks(on: jan1, calendar: utc), 52)
        XCTAssertEqual(PayFrequency.biweekly.remainingPaychecks(on: jan1, calendar: utc), 26)
    }

    func testPerPaycheckSplitsAnnualSavingsOverRemainingChecks() {
        let jan1 = date(2026, 1, 1)
        let boost = PaycheckCalculator.boost(
            overtimeDeduction: 12_500,
            carLoanDeduction: 1_200,
            filingStatus: .single,
            magi: 90_000,
            frequency: .biweekly,
            on: jan1,
            calendar: utc
        )
        XCTAssertEqual(boost.annualDeduction, 13_700)
        XCTAssertEqual(boost.marginalRate, money("0.22"))
        XCTAssertEqual(boost.annualTaxSaved, 3_014)
        XCTAssertEqual(boost.remainingPaychecks, 26)
        XCTAssertEqual(boost.perPaycheck, money("115.92"))
    }

    func testCarLoanIsAddedOnlyWhenProvided() {
        let jan1 = date(2026, 1, 1)
        let without = PaycheckCalculator.boost(
            overtimeDeduction: 1_000,
            carLoanDeduction: 0,
            filingStatus: .single,
            magi: 40_000,
            frequency: .monthly,
            on: jan1,
            calendar: utc
        )
        let withLoan = PaycheckCalculator.boost(
            overtimeDeduction: 1_000,
            carLoanDeduction: 500,
            filingStatus: .single,
            magi: 40_000,
            frequency: .monthly,
            on: jan1,
            calendar: utc
        )
        let negative = PaycheckCalculator.boost(
            overtimeDeduction: 1_000,
            carLoanDeduction: -20,
            filingStatus: .single,
            magi: 40_000,
            frequency: .monthly,
            on: jan1,
            calendar: utc
        )
        XCTAssertEqual(without.annualDeduction, 1_000)
        XCTAssertEqual(withLoan.annualDeduction, 1_500)
        XCTAssertEqual(negative.annualDeduction, 1_000)
        XCTAssertEqual(without.marginalRate, money("0.12"))
        XCTAssertEqual(without.annualTaxSaved, 120)
        XCTAssertEqual(without.remainingPaychecks, 12)
        XCTAssertEqual(without.perPaycheck, 10)
    }

    func testYearEndFloorUsesTheWholeAnnualAmountOnTheLastSlot() {
        let dec31 = date(2026, 12, 31)
        let boost = PaycheckCalculator.boost(
            overtimeDeduction: 1_000,
            carLoanDeduction: 0,
            filingStatus: .single,
            magi: 10_000,
            frequency: .weekly,
            on: dec31,
            calendar: utc
        )
        XCTAssertEqual(boost.marginalRate, money("0.10"))
        XCTAssertEqual(boost.annualTaxSaved, 100)
        XCTAssertEqual(boost.remainingPaychecks, 1)
        XCTAssertEqual(boost.perPaycheck, boost.annualTaxSaved)
    }

    func testRepeatingDivisionRoundsToCents() {
        XCTAssertEqual(PaycheckCalculator.perPaycheck(annualTaxSaved: 100, remainingPaychecks: 3), money("33.33"))
        XCTAssertEqual(PaycheckCalculator.perPaycheck(annualTaxSaved: 3_014, remainingPaychecks: 3), money("1004.67"))
        XCTAssertEqual(PaycheckCalculator.perPaycheck(annualTaxSaved: 3_014, remainingPaychecks: 0), 3_014)
    }

    func testOctober2026BiweeklySplit() {
        let boost = PaycheckCalculator.boost(
            overtimeDeduction: 12_500,
            carLoanDeduction: 1_200,
            filingStatus: .single,
            magi: 90_000,
            frequency: .biweekly,
            on: date(2026, 10, 29),
            calendar: utc
        )
        XCTAssertEqual(boost.remainingPaychecks, 4)
        XCTAssertEqual(boost.perPaycheck, money("753.50"))
    }

    func testAnnualPremiumUsesTypicalWeekThenLoggedRemainder() {
        XCTAssertEqual(
            PaycheckCalculator.annualQualifiedPremium(logged: 0, weeksLogged: 0, typicalWeekPremium: 150),
            7_800
        )
        XCTAssertEqual(
            PaycheckCalculator.annualQualifiedPremium(logged: 1_500, weeksLogged: 10, typicalWeekPremium: 999),
            7_800
        )
        XCTAssertEqual(
            PaycheckCalculator.annualQualifiedPremium(logged: 7_800, weeksLogged: 52, typicalWeekPremium: 1),
            7_800
        )
        XCTAssertEqual(
            PaycheckCalculator.annualQualifiedPremium(logged: 100, weeksLogged: 60, typicalWeekPremium: 50),
            100
        )
    }

    func test2026BracketBoundaries() {
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 0), money("0.10"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: -100), money("0.10"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 12_400), money("0.10"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: money("12400.01")), money("0.12"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 50_400), money("0.12"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: money("50400.01")), money("0.22"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 105_700), money("0.22"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 201_775), money("0.24"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: money("201775.01")), money("0.32"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: 640_600), money("0.35"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .single, magi: money("640600.01")), money("0.37"))

        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingJointly, magi: 24_800), money("0.10"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingJointly, magi: 100_800), money("0.12"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingJointly, magi: money("100800.01")), money("0.22"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingJointly, magi: 768_700), money("0.35"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .qualifyingSurvivingSpouse, magi: money("768700.01")), money("0.37"))

        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 17_700), money("0.10"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 67_450), money("0.12"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 105_700), money("0.22"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 201_750), money("0.24"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 256_200), money("0.32"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: 640_600), money("0.35"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .headOfHousehold, magi: money("640600.01")), money("0.37"))

        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingSeparately, magi: 256_225), money("0.32"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingSeparately, magi: 384_350), money("0.35"))
        XCTAssertEqual(FederalBracket.marginalRate(filingStatus: .marriedFilingSeparately, magi: money("384350.01")), money("0.37"))
    }
}
