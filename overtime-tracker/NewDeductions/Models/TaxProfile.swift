import Foundation
import OvertimeCore
import SwiftData

@Model
final class TaxProfile {
    var taxYear: Int
    var filingStatusRaw: String
    var estimatedMAGI: Decimal
    /// Federal marginal rate as a fraction (0.22 for 22%). Matches `OvertimeCalculator.estimatedTaxSavings`.
    var marginalRate: Decimal
    var hasSSN: Bool
    /// Onboarding answers. The PLAN model snippet did not include them; they are stored so the
    /// eligibility step is not discarded. See the README.
    var isHourlyNonExempt: Bool
    var paidOvertimeOver40: Bool
    var acceptedDisclaimer: Bool
    /// Set when onboarding asks about a new car. Optional so a build-1 store opens without a migration.
    var wantsCarLoan: Bool?

    init(
        taxYear: Int,
        filingStatus: FilingStatus,
        estimatedMAGI: Decimal,
        marginalRate: Decimal,
        hasSSN: Bool,
        isHourlyNonExempt: Bool,
        paidOvertimeOver40: Bool,
        acceptedDisclaimer: Bool,
        wantsCarLoan: Bool? = nil
    ) {
        self.taxYear = taxYear
        self.filingStatusRaw = filingStatus.rawValue
        self.estimatedMAGI = estimatedMAGI
        self.marginalRate = marginalRate
        self.hasSSN = hasSSN
        self.isHourlyNonExempt = isHourlyNonExempt
        self.paidOvertimeOver40 = paidOvertimeOver40
        self.acceptedDisclaimer = acceptedDisclaimer
        self.wantsCarLoan = wantsCarLoan
    }

    var filingStatus: FilingStatus {
        get { FilingStatus(rawValue: filingStatusRaw) ?? .single }
        set { filingStatusRaw = newValue.rawValue }
    }

    /// Calendar year clamped to the deduction window, 2025–2028.
    static func defaultTaxYear(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: now)
        return min(max(year, 2025), 2028)
    }
}
