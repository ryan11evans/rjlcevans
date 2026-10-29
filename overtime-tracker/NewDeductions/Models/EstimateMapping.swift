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
            return "Married filing separately doesn't qualify, so the overtime estimate is $0. You can change this in Settings."
        }
        if !profile.hasSSN {
            return "A valid Social Security number is required, so the overtime estimate is $0. You can update that in Settings."
        }
        if !profile.isHourlyNonExempt {
            return "Salaried exempt work usually doesn't qualify, so the overtime estimate is $0. The car-loan estimate is separate."
        }
        if !profile.paidOvertimeOver40 {
            return "Without time-and-a-half after 40 hours, the overtime estimate is $0."
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
            marginalRate: 0,
            hasValidSSN: profile.hasSSN
        )
        if blocksDeduction(profile) != nil {
            estimate.estimatedDeduction = 0
            estimate.estimatedTaxSaved = 0
        } else {
            estimate.estimatedTaxSaved = FederalBracket.estimate(
                magi: profile.estimatedMAGI,
                filingStatus: profile.filingStatus,
                schedule1ADeductions: estimate.estimatedDeduction
            ).taxSaved
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
        let combined = overtime.estimatedDeduction + carDeduction
        let tax = FederalBracket.estimate(
            magi: profile.estimatedMAGI,
            filingStatus: profile.filingStatus,
            schedule1ADeductions: combined
        )
        let schedule = Schedule1AEstimate(
            overtimeDeduction: overtime.estimatedDeduction,
            carLoanDeduction: carDeduction,
            combinedDeduction: combined,
            estimatedTaxSaved: tax.taxSaved
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
    static let transitionYear = "Employers may report the qualified overtime premium separately for the 2025 transition year."

    static func headline(_ comparison: CodeTTComparison) -> String {
        switch comparison {
        case .notOnW2: "Not on this W-2"
        case .match: "Match"
        case .possibleShortfall: "Possible shortfall"
        case .overage: "Overage"
        }
    }

    static func dollars(_ comparison: CodeTTComparison) -> Decimal? {
        switch comparison {
        case .notOnW2, .match: nil
        case .possibleShortfall(let dollars), .overage(let dollars): dollars
        }
    }

    static func explanation(comparison: CodeTTComparison, taxYear: Int) -> String {
        let transition = taxYear == 2025 ? " \(transitionYear)" : ""
        switch comparison {
        case .notOnW2:
            return "You marked code TT as not on this W-2, so there is no dollar comparison yet. \(transitionYear) Estimate only, not tax advice."
        case .match:
            return "Code TT matches the qualified premium in this log. Both figures are estimates.\(transition)"
        case .possibleShortfall(let dollars):
            return "Possible shortfall of \(AppFormatting.currency(dollars)). The W-2 amount is lower than this log (estimate). Hours, the base rate, or weekly extras may not match payroll.\(transition)"
        case .overage(let dollars):
            return "Overage of \(AppFormatting.currency(dollars)). The W-2 amount is higher than this log (estimate). The log may be missing weeks, or the W-2 may include pay this app does not count as the FLSA half-time premium.\(transition)"
        }
    }

    static func payrollNote(taxYear: Int, computed: Decimal, reported: Decimal?, comparison: CodeTTComparison) -> String {
        let logged = AppFormatting.currency(computed)
        let mentionTransition = taxYear == 2025 || comparison == .notOnW2
        let transition = mentionTransition ? " \(transitionYear)" : ""
        switch comparison {
        case .notOnW2:
            return """
            Hello,

            My Form W-2 for tax year \(taxYear) does not show Box 12 code TT. Could you confirm whether that code should be there, and the amount if so? My own log estimates the qualified FLSA overtime premium (the extra half of time-and-a-half, not the full overtime pay) at \(logged).\(transition)

            This is an estimate from my records, not a tax filing. Thank you for checking.
            """
        case .match:
            return """
            Hello,

            Could you verify Box 12 code TT on my Form W-2 for tax year \(taxYear)? Code TT should be the qualified overtime premium, the extra half of time-and-a-half under the FLSA, not the full overtime pay.

            My log estimates that premium at \(logged), and the W-2 shows the same amount. I would appreciate a confirmation.\(transition)

            This is an estimate from my records, not a tax filing. Thank you.
            """
        case .possibleShortfall(let dollars):
            let shown = reported.map(AppFormatting.currency) ?? AppFormatting.currency(computed - dollars)
            return gapNote(taxYear: taxYear, logged: logged, reported: shown, gap: AppFormatting.currency(dollars), direction: "lower", transition: transition)
        case .overage(let dollars):
            let shown = reported.map(AppFormatting.currency) ?? AppFormatting.currency(computed + dollars)
            return gapNote(taxYear: taxYear, logged: logged, reported: shown, gap: AppFormatting.currency(dollars), direction: "higher", transition: transition)
        }
    }

    private static func gapNote(taxYear: Int, logged: String, reported: String, gap: String, direction: String, transition: String) -> String {
        """
        Hello,

        Could you verify Box 12 code TT on my Form W-2 for tax year \(taxYear)? Code TT should be the qualified overtime premium, the extra half of time-and-a-half under the FLSA, not the full overtime pay.

        My log estimates that premium at \(logged). The W-2 shows \(reported). The difference is \(gap) (the W-2 is \(direction)).\(transition)

        This is an estimate from my records, not a tax filing. Thank you for checking.
        """
    }
}
