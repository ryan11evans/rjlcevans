import Foundation
import OvertimeCore
import SwiftData

extension Week {
    var workWeek: WorkWeek {
        WorkWeek(hoursWorked: hoursWorked, hourlyRate: hourlyRate, includableExtras: includableExtras)
    }

    var result: WeekResult {
        OvertimeCalculator.compute(workWeek)
    }
}

extension Employer {
    /// Workweeks that overlap `taxYear`, newest first.
    func loggedWeeks(taxYear: Int, calendar: Calendar) -> [Week] {
        let earliest = WorkweekDates.earliestStart(taxYear: taxYear, weekday: workweekStartsOn, calendar: calendar)
        let latest = WorkweekDates.latestStart(taxYear: taxYear, weekday: workweekStartsOn, calendar: calendar)
        return weeks
            .filter { week in
                let start = calendar.startOfDay(for: week.startDate)
                return start >= earliest && start <= latest
            }
            .sorted { $0.startDate > $1.startDate }
    }
}

extension Vehicle {
    var assemblySignal: AssemblySignal {
        get { AssemblySignal(rawValue: assemblySignalRaw) ?? .unknown }
        set { assemblySignalRaw = newValue.rawValue }
    }

    var vehicleType: VehicleType {
        get { VehicleType(rawValue: vehicleTypeRaw) ?? .other }
        set { vehicleTypeRaw = newValue.rawValue }
    }

    var primaryLoan: VehicleLoan? { loans.first }

    var displayTitle: String {
        let parts = [modelYear.map(String.init), make, model].compactMap { $0 }
        return parts.isEmpty ? "Vehicle" : parts.joined(separator: " ")
    }
}

enum AssemblyCopy {
    static func line(_ signal: AssemblySignal) -> String {
        switch signal {
        case .usPlant:
            "US final assembly"
        case .stickerConfirmedUS:
            "US final assembly (door-jamb label)"
        case .nonUSPlant:
            "Not eligible"
        case .unknown:
            "Unknown, check the door-jamb label"
        }
    }
}

enum OvertimeEligibility {
    /// Why the overtime deduction is forced to $0, or nil when the profile can have one.
    static func blocksDeduction(_ profile: TaxProfile) -> String? {
        if profile.filingStatus == .marriedFilingSeparately {
            return "Married filing separately does not qualify. The estimated overtime deduction is $0."
        }
        if !profile.hasSSN {
            return "A valid Social Security number is required. The estimated overtime deduction is $0."
        }
        if !profile.isHourlyNonExempt {
            return "This profile is not hourly and non-exempt. The estimated overtime deduction is $0."
        }
        if !profile.paidOvertimeOver40 {
            return "This profile is not paid overtime after 40 hours in a workweek. The estimated overtime deduction is $0."
        }
        return nil
    }

    /// Ring cap. Married filing separately is $0; every other status uses the statutory cap.
    static func cap(_ profile: TaxProfile) -> Decimal {
        profile.filingStatus == .marriedFilingSeparately ? 0 : profile.filingStatus.cap
    }

    static func yearEstimate(weeks: [Week], profile: TaxProfile) -> OvertimeYearEstimate {
        var estimate = OvertimeCalculator.yearEstimate(
            weeks: weeks.map(\.workWeek),
            filingStatus: profile.filingStatus,
            magi: profile.estimatedMAGI,
            marginalRate: profile.marginalRate,
            hasValidSSN: profile.hasSSN
        )
        if blocksDeduction(profile) != nil {
            estimate.estimatedDeduction = 0
            estimate.estimatedTaxSaved = 0
        }
        return estimate
    }
}

struct QualifyingInterest: Equatable, Identifiable {
    var id: String { vin }
    var vin: String
    var title: String
    var projected: Decimal
    var used: Decimal
    var usedForm1098: Bool
    var included: Bool
}

enum CarLoanMath {
    static func resolvedGVWR(pounds: Int?, confirmedUnderLimit: Bool?) -> Int? {
        if let pounds { return pounds }
        if confirmedUnderLimit == true { return 13_999 }
        if confirmedUnderLimit == false { return 14_000 }
        return nil
    }

    static func facts(vehicle: Vehicle, loan: VehicleLoan) -> VehicleLoanFacts {
        VehicleLoanFacts(
            originationDate: loan.originationDate,
            isNew: vehicle.isNew,
            personalUse: loan.personalUse,
            firstLien: loan.firstLien,
            isLease: loan.isLease,
            salvageOrScrap: loan.salvageOrScrap ?? false,
            relatedPartyLender: loan.relatedPartyLender ?? false,
            vehicleType: vehicle.vehicleType,
            gvwrPounds: resolvedGVWR(pounds: vehicle.gvwrPounds, confirmedUnderLimit: vehicle.userConfirmedGVWRUnderLimit),
            assembly: vehicle.assemblySignal
        )
    }

    static func projectedInterest(principal: Decimal, aprPercent: Decimal, termMonths: Int, firstPayment: Date, taxYear: Int, calendar: Calendar) -> Decimal? {
        guard principal > 0, termMonths > 0, aprPercent >= 0 else { return nil }
        let parts = calendar.dateComponents([.year, .month], from: firstPayment)
        guard let year = parts.year, let month = parts.month else { return nil }
        return CarLoanInterestCalculator.projectedInterest(
            principal: principal,
            aprPercent: aprPercent,
            months: termMonths,
            firstPaymentYear: year,
            firstPaymentMonth: month,
            taxYear: taxYear
        )
    }

    /// Saved loans only. A loan counts toward the deduction when the checklist verdict is eligible.
    static func qualifying(vehicles: [Vehicle], taxYear: Int, calendar: Calendar) -> [QualifyingInterest] {
        vehicles.map { vehicle in
            guard let loan = vehicle.primaryLoan,
                  let projected = projectedInterest(
                    principal: loan.principal,
                    aprPercent: loan.aprPercent,
                    termMonths: loan.termMonths,
                    firstPayment: loan.firstPaymentDate,
                    taxYear: taxYear,
                    calendar: calendar
                  ) else {
                return QualifyingInterest(
                    vin: vehicle.vin,
                    title: vehicle.displayTitle,
                    projected: 0,
                    used: 0,
                    usedForm1098: false,
                    included: false
                )
            }
            let actual = loan.actualInterest[taxYear]
            let used = actual ?? projected
            let verdict = CarLoanInterestCalculator.verdict(facts(vehicle: vehicle, loan: loan))
            return QualifyingInterest(
                vin: vehicle.vin,
                title: vehicle.displayTitle,
                projected: projected,
                used: used,
                usedForm1098: actual != nil,
                included: verdict == .eligible
            )
        }
    }

    static func deduction(vehicles: [Vehicle], profile: TaxProfile, calendar: Calendar) -> Decimal {
        let amounts = qualifying(vehicles: vehicles, taxYear: profile.taxYear, calendar: calendar)
            .filter(\.included)
            .map(\.used)
        return CarLoanInterestCalculator.deduction(
            loanInterest: amounts,
            magi: profile.estimatedMAGI,
            status: profile.filingStatus,
            taxYear: profile.taxYear
        )
    }

    static func reasons(for facts: VehicleLoanFacts) -> [String] {
        var reasons: [String] = []
        let cutoff = CarLoanInterestCalculator.utc.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        if facts.originationDate < cutoff {
            reasons.append("The loan must be originated after December 31, 2024.")
        }
        if facts.isLease { reasons.append("A lease does not qualify.") }
        if facts.salvageOrScrap { reasons.append("A salvage, scrap, or parts vehicle does not qualify.") }
        if facts.relatedPartyLender { reasons.append("A loan from a related party does not qualify.") }
        if !facts.vehicleType.qualifies { reasons.append("This vehicle type does not qualify.") }
        if let pounds = facts.gvwrPounds, pounds >= 14_000 {
            reasons.append("GVWR must be under 14,000 lb.")
        }
        if facts.isNew == false { reasons.append("Original use has to start with you. A used vehicle does not qualify.") }
        if facts.personalUse == false { reasons.append("More than half the use has to be personal.") }
        if facts.firstLien == false { reasons.append("The loan has to be a first lien.") }
        if facts.assembly == .nonUSPlant { reasons.append("Final assembly is not in the United States.") }
        if facts.isNew == nil { reasons.append("Say whether the vehicle is new.") }
        if facts.personalUse == nil { reasons.append("Say whether personal use is more than half.") }
        if facts.firstLien == nil { reasons.append("Say whether this is a first lien.") }
        if facts.gvwrPounds == nil { reasons.append("GVWR is unknown. Confirm it is under 14,000 lb.") }
        if facts.assembly == .unknown { reasons.append("Unknown, check the door-jamb label.") }
        return reasons
    }

    static func verdictTitle(_ verdict: EligibilityVerdict) -> String {
        switch verdict {
        case .eligible: "Eligible (estimate)"
        case .likely: "More answers needed"
        case .checkSticker: "Unknown, check the door-jamb label"
        case .notEligible: "Not eligible"
        }
    }
}

struct ReturnEstimate {
    var weeks: [Week]
    var overtime: OvertimeYearEstimate
    var overtimeNote: String?
    var carLines: [QualifyingInterest]
    var carDeduction: Decimal
    var schedule: Schedule1AEstimate
    var w4Line4b: Decimal
}

enum ReturnEstimateBuilder {
    static func make(employer: Employer?, profile: TaxProfile, vehicles: [Vehicle], calendar: Calendar) -> ReturnEstimate {
        let weeks = employer?.loggedWeeks(taxYear: profile.taxYear, calendar: calendar) ?? []
        let overtime = OvertimeEligibility.yearEstimate(weeks: weeks, profile: profile)
        let carLines = CarLoanMath.qualifying(vehicles: vehicles, taxYear: profile.taxYear, calendar: calendar)
        let carDeduction = CarLoanMath.deduction(vehicles: vehicles, profile: profile, calendar: calendar)
        let schedule = Schedule1ACalculator.estimate(
            overtimeDeduction: overtime.estimatedDeduction,
            carLoanDeduction: carDeduction,
            marginalRate: profile.marginalRate
        )
        return ReturnEstimate(
            weeks: weeks,
            overtime: overtime,
            overtimeNote: OvertimeEligibility.blocksDeduction(profile),
            carLines: carLines,
            carDeduction: carDeduction,
            schedule: schedule,
            w4Line4b: Schedule1ACalculator.suggestedW4Line4b(
                overtimeDeduction: overtime.estimatedDeduction,
                carLoanDeduction: carDeduction
            )
        )
    }
}

enum EstimateProgress {
    static func fraction(amount: Decimal, cap: Decimal) -> Double {
        guard cap > 0, amount > 0 else { return 0 }
        let value = (amount as NSDecimalNumber).doubleValue / (cap as NSDecimalNumber).doubleValue
        if value.isNaN || value.isInfinite { return 0 }
        return min(max(value, 0), 1)
    }
}

enum CodeTTCopy {
    static func explanation(difference: CodeTTDifference) -> String {
        let gap = difference.reportedMinusComputed
        if gap == 0 {
            return "Code TT matches the qualified premium computed from the weeks in this log. Both figures are still estimates until you file."
        }
        if gap > 0 {
            return "Code TT is \(AppFormatting.currency(gap)) higher than this log (estimate). The log may be missing weeks, or the W-2 may include pay this app does not count as the FLSA half-time premium."
        }
        return "Code TT is \(AppFormatting.currency(-gap)) lower than this log (estimate). The hours, base rate, or weekly extras may not match payroll, or the log may include weeks the W-2 does not."
    }
}
