import Foundation

/// Pay frequency and the estimated per-paycheck split of the annual federal tax savings.
/// ESTIMATES ONLY — not tax advice. Real paydays are whatever the employer uses.
public enum PayFrequency: String, Codable, CaseIterable, Hashable, Sendable {
    case weekly
    case biweekly
    case semimonthly
    case monthly

    /// Estimated paychecks in a full year. Biweekly uses 26, not 27.
    public var periodsPerYear: Int {
        switch self {
        case .weekly: 52
        case .biweekly: 26
        case .semimonthly: 24
        case .monthly: 12
        }
    }

    /// Estimated paychecks left in the calendar year of `date`, counting a payday that falls on `date`.
    ///
    /// - weekly: every Friday
    /// - biweekly: every other Friday, anchored on the first Friday of that year
    /// - semimonthly: the 15th and the last day of each month
    /// - monthly: the last day of each month
    ///
    /// The result is at least 1, so a date after the last payday still divides.
    public func remainingPaychecks(on date: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: start)
        let count: Int
        switch self {
        case .weekly:
            count = Self.fridayCount(year: year, strideDays: 7, from: start, calendar: calendar)
        case .biweekly:
            count = Self.fridayCount(year: year, strideDays: 14, from: start, calendar: calendar)
        case .semimonthly:
            count = Self.monthDateCount(year: year, from: start, calendar: calendar, includeFifteenth: true)
        case .monthly:
            count = Self.monthDateCount(year: year, from: start, calendar: calendar, includeFifteenth: false)
        }
        return max(count, 1)
    }

    private static func fridayCount(year: Int, strideDays: Int, from start: Date, calendar: Calendar) -> Int {
        guard let anchor = firstFriday(of: year, calendar: calendar),
              let end = yearEnd(year, calendar: calendar) else { return 0 }
        var cursor = anchor
        if cursor < start {
            let days = calendar.dateComponents([.day], from: cursor, to: start).day ?? 0
            let steps = (days + strideDays - 1) / strideDays
            guard let advanced = calendar.date(byAdding: .day, value: steps * strideDays, to: cursor) else { return 0 }
            cursor = advanced
        }
        var count = 0
        while cursor <= end {
            count += 1
            guard let next = calendar.date(byAdding: .day, value: strideDays, to: cursor), next > cursor else { break }
            cursor = next
        }
        return count
    }

    /// Friday is `Calendar` weekday 6 (Sunday = 1), independent of the locale's first weekday.
    private static func firstFriday(of year: Int, calendar: Calendar) -> Date? {
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }
        let day = calendar.startOfDay(for: jan1)
        let weekday = calendar.component(.weekday, from: day)
        let delta = (6 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: delta, to: day)
    }

    private static func yearEnd(_ year: Int, calendar: Calendar) -> Date? {
        guard let dec31 = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else { return nil }
        return calendar.startOfDay(for: dec31)
    }

    private static func monthDateCount(year: Int, from start: Date, calendar: Calendar, includeFifteenth: Bool) -> Int {
        var count = 0
        for month in 1...12 {
            if includeFifteenth,
               let fifteenth = calendar.date(from: DateComponents(year: year, month: month, day: 15)),
               calendar.startOfDay(for: fifteenth) >= start {
                count += 1
            }
            let nextMonth: Date?
            if month == 12 {
                nextMonth = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
            } else {
                nextMonth = calendar.date(from: DateComponents(year: year, month: month + 1, day: 1))
            }
            guard let nextMonth, let last = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { continue }
            if calendar.startOfDay(for: last) >= start {
                count += 1
            }
        }
        return count
    }
}

/// 2026 federal income-tax rate tables (Rev. Proc. 2025-32), used only as an estimate.
///
/// The tables apply to taxable income. This lookup treats estimated MAGI as if it were
/// taxable income, which can put the rate a bracket high. Label the result as an estimate.
/// Not tax advice.
public enum FederalBracket {
    public static func marginalRate(filingStatus: FilingStatus, magi: Decimal) -> Decimal {
        let income = max(magi, 0)
        let caps = ceilings(for: filingStatus)
        for (index, ceiling) in caps.enumerated() where income <= ceiling {
            return rates[index]
        }
        return rates[rates.count - 1]
    }

    /// Inclusive top of each bracket, in order, for the 10% through 35% rates.
    /// Income above the last ceiling is 37%.
    private static func ceilings(for status: FilingStatus) -> [Decimal] {
        switch status {
        case .marriedFilingJointly, .qualifyingSurvivingSpouse:
            return [24_800, 100_800, 211_400, 403_550, 512_450, 768_700]
        case .headOfHousehold:
            return [17_700, 67_450, 105_700, 201_750, 256_200, 640_600]
        case .marriedFilingSeparately:
            return [12_400, 50_400, 105_700, 201_775, 256_225, 384_350]
        case .single:
            return [12_400, 50_400, 105_700, 201_775, 256_225, 640_600]
        }
    }

    private static let rates: [Decimal] = [
        posix("0.10"), posix("0.12"), posix("0.22"), posix("0.24"), posix("0.32"), posix("0.35"), posix("0.37")
    ]

    private static func posix(_ literal: String) -> Decimal {
        Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX"))!
    }
}

public struct PaycheckBoost: Equatable, Sendable {
    /// Overtime deduction plus car-loan deduction, each already after its own cap and phase-out.
    public var annualDeduction: Decimal
    /// Estimated 2026 marginal rate from filing status and MAGI.
    public var marginalRate: Decimal
    public var annualTaxSaved: Decimal
    public var payFrequency: PayFrequency
    public var remainingPaychecks: Int
    /// `annualTaxSaved` divided by `remainingPaychecks`, rounded to cents.
    public var perPaycheck: Decimal

    public init(annualDeduction: Decimal,
                marginalRate: Decimal,
                annualTaxSaved: Decimal,
                payFrequency: PayFrequency,
                remainingPaychecks: Int,
                perPaycheck: Decimal) {
        self.annualDeduction = annualDeduction
        self.marginalRate = marginalRate
        self.annualTaxSaved = annualTaxSaved
        self.payFrequency = payFrequency
        self.remainingPaychecks = remainingPaychecks
        self.perPaycheck = perPaycheck
    }
}

public enum PaycheckCalculator {
    /// Qualified premium for the year.
    ///
    /// With no logged weeks, this is one typical week's premium carried across 52 weeks.
    /// With logged weeks, it is the logged premium plus that average for each of the remaining
    /// weeks in a 52-week year. That is the same total as the logged average × 52.
    /// Estimate only, not tax advice.
    public static func annualQualifiedPremium(logged: Decimal, weeksLogged: Int, typicalWeekPremium: Decimal) -> Decimal {
        if weeksLogged > 0 {
            let average = logged / Decimal(weeksLogged)
            let remaining = Decimal(max(0, 52 - weeksLogged))
            return round2(logged + average * remaining)
        }
        return round2(max(typicalWeekPremium, 0) * 52)
    }

    /// Annual estimated federal tax saved, spread over the paychecks still left this year.
    /// Pass `0` for a deduction the person does not have. Negative inputs are treated as zero.
    public static func boost(overtimeDeduction: Decimal,
                             carLoanDeduction: Decimal,
                             filingStatus: FilingStatus,
                             magi: Decimal,
                             frequency: PayFrequency,
                             on date: Date,
                             calendar: Calendar) -> PaycheckBoost {
        let annual = max(overtimeDeduction, 0) + max(carLoanDeduction, 0)
        let rate = FederalBracket.marginalRate(filingStatus: filingStatus, magi: magi)
        let saved = OvertimeCalculator.estimatedTaxSavings(deduction: annual, marginalRate: rate)
        let remaining = frequency.remainingPaychecks(on: date, calendar: calendar)
        return PaycheckBoost(
            annualDeduction: annual,
            marginalRate: rate,
            annualTaxSaved: saved,
            payFrequency: frequency,
            remainingPaychecks: remaining,
            perPaycheck: perPaycheck(annualTaxSaved: saved, remainingPaychecks: remaining)
        )
    }

    public static func perPaycheck(annualTaxSaved: Decimal, remainingPaychecks: Int) -> Decimal {
        let periods = Decimal(max(remainingPaychecks, 1))
        return round2(annualTaxSaved / periods)
    }

    static func round2(_ value: Decimal) -> Decimal {
        var v = value, r = Decimal()
        NSDecimalRound(&r, &v, 2, .bankers)
        return r
    }
}
