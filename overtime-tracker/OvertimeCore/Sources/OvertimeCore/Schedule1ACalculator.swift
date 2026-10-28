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
}
