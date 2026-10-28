import Foundation
import SwiftData

@Model
final class Employer {
    var name: String
    /// Weekday the FLSA workweek starts on. 1 = Sunday … 7 = Saturday (`Calendar` weekday).
    var workweekStartsOn: Int
    var defaultRate: Decimal

    @Relationship(deleteRule: .cascade, inverse: \Week.employer)
    var weeks: [Week]

    /// JSON from `YearAmountStorage`. Tax year → W-2 Box 12 code TT.
    var codeTTData: Data

    init(name: String, workweekStartsOn: Int, defaultRate: Decimal, codeTT: [Int: Decimal] = [:]) {
        self.name = name
        self.workweekStartsOn = workweekStartsOn
        self.defaultRate = defaultRate
        self.weeks = []
        self.codeTTData = YearAmountStorage.encode(codeTT)
    }

    /// Assign the whole dictionary (`employer.codeTT = updated`). Subscript writes on the
    /// returned value do not persist; use `setCodeTT(_:for:)`.
    var codeTT: [Int: Decimal] {
        get { YearAmountStorage.decode(codeTTData) }
        set { codeTTData = YearAmountStorage.encode(newValue) }
    }

    func setCodeTT(_ amount: Decimal?, for taxYear: Int) {
        var map = codeTT
        if let amount {
            map[taxYear] = amount
        } else {
            map.removeValue(forKey: taxYear)
        }
        codeTT = map
    }
}
