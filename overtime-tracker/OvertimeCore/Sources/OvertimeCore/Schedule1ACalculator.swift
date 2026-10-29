import Foundation

/// Combined Schedule 1-A estimate and the Form W-4 line 4(b) suggestion.
/// ESTIMATES ONLY — not tax advice. Each input deduction is already after its own cap and phase-out.
public struct Schedule1AEstimate: Equatable, Sendable {
    public var overtimeDeduction: Decimal
    public var carLoanDeduction: Decimal
    public var combinedDeduction: Decimal
    public var estimatedTaxSaved: Decimal

    public init(overtimeDeduction: Decimal, carLoanDeduction: Decimal, combinedDeduction: Decimal, estimatedTaxSaved: Decimal) {
        self.overtimeDeduction = overtimeDeduction
        self.carLoanDeduction = carLoanDeduction
        self.combinedDeduction = combinedDeduction
        self.estimatedTaxSaved = estimatedTaxSaved
    }
}

/// W-2 Box 12 code TT compared with the premium computed from the week log.
public struct CodeTTDifference: Equatable, Sendable {
    public var reported: Decimal
    public var computed: Decimal
    /// Code TT minus the log. Positive means the W-2 figure is higher.
    public var reportedMinusComputed: Decimal

    public init(reported: Decimal, computed: Decimal, reportedMinusComputed: Decimal) {
        self.reported = reported
        self.computed = computed
        self.reportedMinusComputed = reportedMinusComputed
    }
}

public enum Schedule1ACalculator {
    public static func estimate(overtimeDeduction: Decimal, carLoanDeduction: Decimal, marginalRate: Decimal) -> Schedule1AEstimate {
        let overtime = max(overtimeDeduction, 0)
        let carLoan = max(carLoanDeduction, 0)
        let combined = overtime + carLoan
        return Schedule1AEstimate(
            overtimeDeduction: overtime,
            carLoanDeduction: carLoan,
            combinedDeduction: combined,
            estimatedTaxSaved: OvertimeCalculator.estimatedTaxSavings(deduction: combined, marginalRate: marginalRate)
        )
    }

    /// Form W-4 Step 4(b), "Deductions". The suggestion is the sum of the two estimated
    /// Schedule 1-A deductions (each already after its cap and phase-out). It is not a
    /// full withholding calculation.
    public static func suggestedW4Line4b(overtimeDeduction: Decimal, carLoanDeduction: Decimal) -> Decimal {
        max(overtimeDeduction, 0) + max(carLoanDeduction, 0)
    }

    public static func compareCodeTT(reported: Decimal, computedPremium: Decimal) -> CodeTTDifference {
        CodeTTDifference(
            reported: reported,
            computed: computedPremium,
            reportedMinusComputed: reported - computedPremium
        )
    }

    /// Amount to type on Form W-4 line 4(b), "Deductions".
    ///
    /// The qualified overtime premium is run through the statutory cap and MAGI phase-out.
    /// Car-loan interest is run through its own cap and phase-out. Pass `0` when there is
    /// no qualifying car loan. A missing SSN or married filing separately makes the
    /// overtime piece $0. This is the projected deduction, not the tax saved, and it is
    /// not a full withholding calculation. Estimate only, not tax advice.
    public static func line4bAmount(projectedQualifiedPremium: Decimal,
                                    carLoanInterest: Decimal,
                                    filingStatus: FilingStatus,
                                    magi: Decimal,
                                    hasValidSSN: Bool = true,
                                    taxYear: Int) -> Decimal {
        let overtime = OvertimeCalculator.deduction(
            qualifiedOvertime: projectedQualifiedPremium,
            filingStatus: filingStatus,
            magi: magi,
            hasValidSSN: hasValidSSN
        )
        let car = CarLoanInterestCalculator.deduction(
            interest: carLoanInterest,
            magi: magi,
            status: filingStatus,
            taxYear: taxYear
        )
        return suggestedW4Line4b(overtimeDeduction: overtime, carLoanDeduction: car)
    }

    /// W-2 Box 12 code TT compared with the qualified premium logged in the app.
    /// `nil` reported means the person marked code TT as not on the W-2.
    /// Both dollar amounts are rounded to cents before the comparison.
    public static func comparison(reported: Decimal?, computedPremium: Decimal) -> CodeTTComparison {
        guard let reported else { return .notOnW2 }
        let w2 = PaycheckCalculator.round2(reported)
        let logged = PaycheckCalculator.round2(computedPremium)
        let gap = w2 - logged
        if gap == 0 { return .match }
        if gap < 0 { return .possibleShortfall(dollars: -gap) }
        return .overage(dollars: gap)
    }
}

/// How a W-2 Box 12 code TT amount compares with the logged qualified premium.
/// Estimate only, not a payroll audit and not tax advice.
public enum CodeTTComparison: Equatable, Sendable {
    case notOnW2
    case match
    /// The W-2 amount is lower. `dollars` is the positive gap (log minus W-2).
    case possibleShortfall(dollars: Decimal)
    /// The W-2 amount is higher. `dollars` is the positive gap (W-2 minus log).
    case overage(dollars: Decimal)

    /// W-2 minus the log, after cents rounding. Nil when code TT is not on the W-2.
    public var reportedMinusLog: Decimal? {
        switch self {
        case .notOnW2: nil
        case .match: 0
        case .possibleShortfall(let dollars): -dollars
        case .overage(let dollars): dollars
        }
    }
}
