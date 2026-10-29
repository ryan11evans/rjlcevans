import Foundation
import SwiftData

@Model
final class Employer {
    var name: String
    /// Weekday the FLSA workweek starts on. 1 = Sunday … 7 = Saturday (`Calendar` weekday).
    var workweekStartsOn: Int
    var defaultRate: Decimal
    /// Typical FLSA overtime hours per week from onboarding. Nil on an older store.
    /// Used only as a projection until a real workweek is logged.
    var typicalOvertimeHours: Decimal?

    @Relationship(deleteRule: .cascade, inverse: \Week.employer)
    var weeks: [Week]

    /// JSON from `YearAmountStorage`. Tax year → W-2 Box 12 code TT.
    var codeTTData: Data
    /// JSON `[Int]` of tax years the user marked "not on my W-2". Nil on an older store.
    var codeTTAbsentData: Data?

    init(name: String, workweekStartsOn: Int, defaultRate: Decimal, typicalOvertimeHours: Decimal? = nil, codeTT: [Int: Decimal] = [:]) {
        self.name = name
        self.workweekStartsOn = workweekStartsOn
        self.defaultRate = defaultRate
        self.typicalOvertimeHours = typicalOvertimeHours
        self.weeks = []
        self.codeTTData = YearAmountStorage.encode(codeTT)
        self.codeTTAbsentData = Data()
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
            var years = Set(codeTTAbsentYears)
            years.remove(taxYear)
            codeTTAbsentYears = Array(years)
        } else {
            map.removeValue(forKey: taxYear)
        }
        codeTT = map
    }

    /// Tax years the user marked code TT as not printed on the W-2.
    var codeTTAbsentYears: [Int] {
        get {
            guard let codeTTAbsentData, !codeTTAbsentData.isEmpty,
                  let years = try? JSONDecoder().decode([Int].self, from: codeTTAbsentData) else { return [] }
            return years
        }
        set {
            codeTTAbsentData = (try? JSONEncoder().encode(newValue.sorted())) ?? Data()
        }
    }

    func markCodeTTNotOnW2(for taxYear: Int) {
        var years = Set(codeTTAbsentYears)
        years.insert(taxYear)
        codeTTAbsentYears = Array(years)
        var map = codeTT
        map.removeValue(forKey: taxYear)
        codeTT = map
    }

    func codeTTIsAbsent(for taxYear: Int) -> Bool {
        codeTT[taxYear] == nil && codeTTAbsentYears.contains(taxYear)
    }
}
