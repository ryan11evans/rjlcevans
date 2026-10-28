import Foundation

/// Pure, UI-free calculator for the federal "No Tax on Overtime" deduction (IRC §225, tax years 2025–2028).
/// ESTIMATES ONLY — not tax advice. Schedule 1-A (Form 1040) is the authority for the final number.
///
/// Rules encoded (sources in PLAN.md):
///  • Qualified OT = only the FLSA-required premium in excess of the regular rate
///    (the "half" of time-and-a-half). State-law, contract, or voluntary OT (e.g. CA daily OT,
///    double-time beyond FLSA) does NOT qualify.
///  • FLSA OT = hours worked over 40 in a fixed 7-day workweek (non-exempt employees).
///  • Cap: $12,500 per return ($25,000 married filing jointly).
///  • Phase-out: reduced by $100 for each $1,000 of MAGI over $150,000 ($300,000 MFJ).
///  • Must have a valid SSN; married filers must file jointly (MFS gets $0).

public enum FilingStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case single, headOfHousehold, marriedFilingJointly, marriedFilingSeparately, qualifyingSurvivingSpouse

    public var cap: Decimal { self == .marriedFilingJointly ? 25_000 : 12_500 }
    public var phaseOutThreshold: Decimal { self == .marriedFilingJointly ? 300_000 : 150_000 }
    public var isEligible: Bool { self != .marriedFilingSeparately }
}

public struct WorkWeek: Equatable, Sendable {
    /// Total hours worked in the FLSA workweek (all jobs at the SAME employer).
    public var hoursWorked: Decimal
    /// Straight-time hourly rate.
    public var hourlyRate: Decimal
    /// Non-discretionary extras for the week (shift differentials, production bonuses) that
    /// FLSA requires to be folded into the regular rate. Default 0.
    public var includableExtras: Decimal

    public init(hoursWorked: Decimal, hourlyRate: Decimal, includableExtras: Decimal = 0) {
        self.hoursWorked = hoursWorked
        self.hourlyRate = hourlyRate
        self.includableExtras = includableExtras
    }
}

public struct OvertimeYearEstimate: Equatable, Sendable {
    public var ytdQualifiedPremium: Decimal
    public var weeksLogged: Int
    public var projectedYearEndPremium: Decimal
    public var estimatedDeduction: Decimal
    public var estimatedTaxSaved: Decimal

    public init(ytdQualifiedPremium: Decimal,
                weeksLogged: Int,
                projectedYearEndPremium: Decimal,
                estimatedDeduction: Decimal,
                estimatedTaxSaved: Decimal) {
        self.ytdQualifiedPremium = ytdQualifiedPremium
        self.weeksLogged = weeksLogged
        self.projectedYearEndPremium = projectedYearEndPremium
        self.estimatedDeduction = estimatedDeduction
        self.estimatedTaxSaved = estimatedTaxSaved
    }
}

public struct WeekResult: Equatable, Sendable {
    public let overtimeHours: Decimal
    public let regularRate: Decimal
    /// What the paycheck should show for OT hours at 1.5x regular rate.
    public let totalOvertimePay: Decimal
    /// The qualified (deductible-before-limits) premium: 0.5 x regular rate x OT hours.
    public let qualifiedPremium: Decimal
}

public enum OvertimeCalculator {
    public static let flsaThresholdHours: Decimal = 40

    /// FLSA regular rate = (straight-time pay for all hours + includable extras) / total hours.
    public static func regularRate(for week: WorkWeek) -> Decimal {
        guard week.hoursWorked > 0 else { return 0 }
        return round2((week.hourlyRate * week.hoursWorked + week.includableExtras) / week.hoursWorked, scale: 4)
    }

    public static func compute(_ week: WorkWeek) -> WeekResult {
        let otHours = max(Decimal(0), week.hoursWorked - flsaThresholdHours)
        let rr = regularRate(for: week)
        let premium = round2(otHours * rr * posixDecimal("0.5"))
        let otPay = round2(otHours * rr * posixDecimal("1.5"))
        return WeekResult(overtimeHours: otHours, regularRate: rr, totalOvertimePay: otPay, qualifiedPremium: premium)
    }

    /// Final estimated deduction for the year after cap and MAGI phase-out.
    /// - Parameters:
    ///   - qualifiedOvertime: total qualified premium (from W-2 Box 12 code TT for 2026+, or the app's log).
    ///   - magi: modified adjusted gross income estimate.
    public static func deduction(qualifiedOvertime: Decimal,
                                 filingStatus: FilingStatus,
                                 magi: Decimal,
                                 hasValidSSN: Bool = true) -> Decimal {
        guard hasValidSSN, filingStatus.isEligible, qualifiedOvertime > 0 else { return 0 }
        let capped = min(qualifiedOvertime, filingStatus.cap)
        let excess = max(Decimal(0), magi - filingStatus.phaseOutThreshold)
        // "$100 for each $1,000" — implemented on whole $1,000 steps. Verify rounding against the
        // final Schedule 1-A instructions before shipping (see PLAN.md, open question Q1).
        var steps = excess / 1_000
        var floored = Decimal()
        NSDecimalRound(&floored, &steps, 0, .down)
        let reduction = floored * 100
        return max(Decimal(0), capped - reduction)
    }

    /// Rough federal tax saved = deduction x marginal bracket. Clearly an estimate.
    public static func estimatedTaxSavings(deduction: Decimal, marginalRate: Decimal) -> Decimal {
        round2(deduction * marginalRate)
    }

    /// Sum of each week's qualified FLSA premium (the 0.5× piece only).
    public static func ytdQualifiedPremium(_ weeks: [WorkWeek]) -> Decimal {
        weeks.reduce(Decimal(0)) { $0 + compute($1).qualifiedPremium }
    }

    /// Projected year-end qualified premium.
    ///
    /// Method: the average qualified premium of the logged workweeks, multiplied by 52.
    /// Weeks that logged $0 of premium stay in the count, so a quiet stretch lowers the run-rate.
    /// This annualizes the observed weekly average across a full 52-week year. It does not add that
    /// average on top of the year-to-date total a second time, and it does not scale by the number
    /// of weeks left on the calendar. With no logged weeks the projection is $0.
    public static func projectedYearEndPremium(ytdQualifiedPremium: Decimal, weeksLogged: Int) -> Decimal {
        guard weeksLogged > 0 else { return 0 }
        return round2(ytdQualifiedPremium / Decimal(weeksLogged) * 52)
    }

    /// Year estimate. The cap and MAGI phase-out run on the projected year-end premium, not the
    /// year-to-date total. Married filing separately and a missing SSN produce a $0 deduction.
    public static func yearEstimate(weeks: [WorkWeek],
                                    filingStatus: FilingStatus,
                                    magi: Decimal,
                                    marginalRate: Decimal,
                                    hasValidSSN: Bool = true) -> OvertimeYearEstimate {
        let ytd = ytdQualifiedPremium(weeks)
        let projected = projectedYearEndPremium(ytdQualifiedPremium: ytd, weeksLogged: weeks.count)
        let estimatedDeduction = deduction(qualifiedOvertime: projected,
                                           filingStatus: filingStatus,
                                           magi: magi,
                                           hasValidSSN: hasValidSSN)
        return OvertimeYearEstimate(
            ytdQualifiedPremium: ytd,
            weeksLogged: weeks.count,
            projectedYearEndPremium: projected,
            estimatedDeduction: estimatedDeduction,
            estimatedTaxSaved: estimatedTaxSavings(deduction: estimatedDeduction, marginalRate: marginalRate)
        )
    }

    static func round2(_ value: Decimal, scale: Int = 2) -> Decimal {
        var v = value, r = Decimal()
        NSDecimalRound(&r, &v, scale, .bankers)
        return r
    }

    /// Rule literals such as "0.5" are not user input. `Decimal(string:)` uses the device
    /// locale, so a comma decimal separator would fail the force-unwrap. Parsing is pinned
    /// to `en_US_POSIX` and the numeric values are unchanged.
    private static func posixDecimal(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
