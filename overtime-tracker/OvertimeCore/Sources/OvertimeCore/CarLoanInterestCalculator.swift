import Foundation

/// Pure, UI-free calculator for the "No Tax on Car Loan Interest" deduction
/// (qualified passenger vehicle loan interest, IRC §163(h)(4), tax years 2025–2028; final regs TD 10054).
/// ESTIMATES ONLY — not tax advice. Schedule 1-A (Form 1040) and Form 1098-VLI are the authority.
///
/// Rules encoded (sources in PLAN.md, section 7):
///  • Cap: $10,000 of interest per return, regardless of filing status (applied BEFORE phase-out).
///  • Phase-out: reduced by $200 for each $1,000 *or portion thereof* of MAGI over $100,000
///    ($200,000 married filing jointly) → zero at $150,000 / $250,000.
///  • Loan originated by the taxpayer after Dec 31, 2024; secured by a first lien; vehicle bought for personal use;
///    new (original use with taxpayer); car/minivan/van/SUV/pickup/motorcycle; GVWR < 14,000 lb; US final assembly.
///  • Excluded: leases, commercial (non-personal) vehicles, salvage title, scrap/parts, related-party loans.
///  • VIN must be reported on the return.

public enum VehicleType: String, Codable, CaseIterable, Sendable {
    case car, minivan, van, suv, pickup, motorcycle, other
    public var qualifies: Bool { self != .other }
}

/// US-assembly signal from NHTSA vPIC `PlantCountry` (or window sticker).
public enum AssemblySignal: String, Codable, Sendable {
    case usPlant          // vPIC PlantCountry == "UNITED STATES (USA)"
    case stickerConfirmedUS // user confirmed "Final Assembly Point" on window sticker is in the US
    case nonUSPlant
    case unknown          // decode failed / field blank / API down
}

public enum EligibilityVerdict: String, Codable, Sendable {
    case eligible       // every check answered and passes
    case likely         // hard checks pass, some user answers still missing
    case checkSticker   // only US assembly is unresolved → ask for window sticker
    case notEligible
}

public struct VehicleLoanFacts: Equatable, Sendable {
    public var originationDate: Date
    public var isNew: Bool?            // original use starts with the taxpayer
    public var personalUse: Bool?      // expected >50% personal use when the loan was taken
    public var firstLien: Bool?
    public var isLease: Bool
    public var salvageOrScrap: Bool
    public var relatedPartyLender: Bool
    public var vehicleType: VehicleType
    public var gvwrPounds: Int?        // nil if unknown; vPIC gives a class range
    public var assembly: AssemblySignal

    public init(originationDate: Date, isNew: Bool?, personalUse: Bool?, firstLien: Bool?, isLease: Bool = false,
                salvageOrScrap: Bool = false, relatedPartyLender: Bool = false, vehicleType: VehicleType,
                gvwrPounds: Int?, assembly: AssemblySignal) {
        self.originationDate = originationDate; self.isNew = isNew; self.personalUse = personalUse
        self.firstLien = firstLien; self.isLease = isLease; self.salvageOrScrap = salvageOrScrap
        self.relatedPartyLender = relatedPartyLender; self.vehicleType = vehicleType
        self.gvwrPounds = gvwrPounds; self.assembly = assembly
    }
}

public enum CarLoanInterestCalculator {
    public static let cap: Decimal = 10_000
    public static let reductionPerStep: Decimal = 200
    public static let firstTaxYear = 2025, lastTaxYear = 2028

    public static func phaseOutThreshold(_ status: FilingStatus) -> Decimal {
        status == .marriedFilingJointly ? 200_000 : 100_000
    }

    public static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    // MARK: Eligibility
    public static func verdict(_ f: VehicleLoanFacts) -> EligibilityVerdict {
        let cutoff = utc.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        if f.originationDate < cutoff || f.isLease || f.salvageOrScrap || f.relatedPartyLender { return .notEligible }
        if !f.vehicleType.qualifies { return .notEligible }
        if let g = f.gvwrPounds, g >= 14_000 { return .notEligible }
        if f.isNew == false || f.personalUse == false || f.firstLien == false { return .notEligible }
        if f.assembly == .nonUSPlant { return .notEligible }
        let answersComplete = f.isNew != nil && f.personalUse != nil && f.firstLien != nil && f.gvwrPounds != nil
        if f.assembly == .unknown { return answersComplete ? .checkSticker : .likely }
        return answersComplete ? .eligible : .likely
    }

    // MARK: Amortization
    static func round2(_ x: Decimal) -> Decimal {
        var v = x, r = Decimal(); NSDecimalRound(&r, &v, 2, .plain); return r
    }

    public static func monthlyPayment(principal: Decimal, aprPercent: Decimal, months: Int) -> Decimal {
        let i = aprPercent / 1200
        if i == 0 { return round2(principal / Decimal(months)) }
        var f: Decimal = 1; for _ in 0..<months { f *= (1 + i) }   // (1+i)^n
        return round2(principal * i * f / (f - 1))
    }

    /// Interest portion of each scheduled payment (cents-rounded, last payment clears the balance).
    public static func interestSchedule(principal: Decimal, aprPercent: Decimal, months: Int) -> [Decimal] {
        let i = aprPercent / 1200, pay = monthlyPayment(principal: principal, aprPercent: aprPercent, months: months)
        var bal = principal, out: [Decimal] = []
        for k in 0..<months {
            let interest = round2(bal * i)
            bal -= (k == months - 1) ? bal : (pay - interest)
            out.append(interest)
        }
        return out
    }

    /// Projected interest for payments that fall due in `taxYear` (first payment in firstPaymentYear/Month).
    public static func projectedInterest(principal: Decimal, aprPercent: Decimal, months: Int,
                                         firstPaymentYear: Int, firstPaymentMonth: Int, taxYear: Int) -> Decimal {
        interestSchedule(principal: principal, aprPercent: aprPercent, months: months).enumerated().reduce(Decimal(0)) { sum, e in
            let year = firstPaymentYear + (firstPaymentMonth - 1 + e.offset) / 12
            return year == taxYear ? sum + e.element : sum
        }
    }

    // MARK: Deduction
    /// `interest`: Form 1098-VLI / actual figure if entered, otherwise projection. Sum across qualifying loans.
    public static func deduction(interest: Decimal, magi: Decimal, status: FilingStatus, taxYear: Int) -> Decimal {
        guard (firstTaxYear...lastTaxYear).contains(taxYear) else { return 0 }
        let capped = min(max(interest, Decimal(0)), cap)
        let excess = magi - phaseOutThreshold(status)
        guard excess > 0 else { return capped }
        var q = excess / 1000, steps = Decimal(); NSDecimalRound(&steps, &q, 0, .up)  // "or portion thereof"
        return max(Decimal(0), capped - steps * reductionPerStep)
    }

    public static func estimatedTaxSaved(deduction: Decimal, marginalRate: Decimal) -> Decimal {
        round2(deduction * marginalRate)
    }
}
