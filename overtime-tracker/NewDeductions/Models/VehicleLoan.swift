import Foundation
import SwiftData

@Model
final class VehicleLoan {
    var lender: String
    var originationDate: Date
    var aprPercent: Decimal
    var principal: Decimal
    var termMonths: Int
    var firstPaymentDate: Date
    var currentBalance: Decimal?
    var personalUse: Bool?
    var firstLien: Bool?
    var isLease: Bool
    var isRefinance: Bool
    /// Nil until the checklist is answered. Treated as false for eligibility.
    var salvageOrScrap: Bool?
    /// Nil until the checklist is answered. Treated as false for eligibility.
    var relatedPartyLender: Bool?
    /// JSON from `YearAmountStorage`. Tax year → Form 1098-VLI interest.
    var actualInterestData: Data
    var vehicle: Vehicle?

    init(
        lender: String,
        originationDate: Date,
        aprPercent: Decimal,
        principal: Decimal,
        termMonths: Int,
        firstPaymentDate: Date,
        currentBalance: Decimal? = nil,
        personalUse: Bool? = nil,
        firstLien: Bool? = nil,
        isLease: Bool = false,
        isRefinance: Bool = false,
        salvageOrScrap: Bool? = nil,
        relatedPartyLender: Bool? = nil,
        actualInterest: [Int: Decimal] = [:],
        vehicle: Vehicle? = nil
    ) {
        self.lender = lender
        self.originationDate = originationDate
        self.aprPercent = aprPercent
        self.principal = principal
        self.termMonths = termMonths
        self.firstPaymentDate = firstPaymentDate
        self.currentBalance = currentBalance
        self.personalUse = personalUse
        self.firstLien = firstLien
        self.isLease = isLease
        self.isRefinance = isRefinance
        self.salvageOrScrap = salvageOrScrap
        self.relatedPartyLender = relatedPartyLender
        self.actualInterestData = YearAmountStorage.encode(actualInterest)
        self.vehicle = vehicle
    }

    /// Assign the whole dictionary. Subscript writes on the returned value do not persist;
    /// use `setActualInterest(_:for:)`.
    var actualInterest: [Int: Decimal] {
        get { YearAmountStorage.decode(actualInterestData) }
        set { actualInterestData = YearAmountStorage.encode(newValue) }
    }

    func setActualInterest(_ amount: Decimal?, for taxYear: Int) {
        var map = actualInterest
        if let amount {
            map[taxYear] = amount
        } else {
            map.removeValue(forKey: taxYear)
        }
        actualInterest = map
    }
}
