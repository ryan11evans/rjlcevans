import Foundation
import OvertimeCore
import SwiftData

@Model
final class Vehicle {
    var vin: String
    var make: String?
    var model: String?
    var modelYear: Int?
    var plantCountry: String?
    var gvwrClass: String?
    /// Parsed pounds when NHTSA gave a range entirely under or entirely over 14,000 lb.
    var gvwrPounds: Int?
    /// Set when NHTSA did not give a usable GVWR and the user answered the checklist.
    var userConfirmedGVWRUnderLimit: Bool?
    var vehicleTypeRaw: String
    var assemblySignalRaw: String
    var isNew: Bool?
    var stickerConfirmedUS: Bool?
    var decodedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \VehicleLoan.vehicle)
    var loans: [VehicleLoan]

    init(
        vin: String,
        make: String? = nil,
        model: String? = nil,
        modelYear: Int? = nil,
        plantCountry: String? = nil,
        gvwrClass: String? = nil,
        gvwrPounds: Int? = nil,
        userConfirmedGVWRUnderLimit: Bool? = nil,
        vehicleTypeRaw: String = VehicleType.car.rawValue,
        assemblySignalRaw: String = AssemblySignal.unknown.rawValue,
        isNew: Bool? = nil,
        stickerConfirmedUS: Bool? = nil,
        decodedAt: Date? = nil
    ) {
        self.vin = vin
        self.make = make
        self.model = model
        self.modelYear = modelYear
        self.plantCountry = plantCountry
        self.gvwrClass = gvwrClass
        self.gvwrPounds = gvwrPounds
        self.userConfirmedGVWRUnderLimit = userConfirmedGVWRUnderLimit
        self.vehicleTypeRaw = vehicleTypeRaw
        self.assemblySignalRaw = assemblySignalRaw
        self.isNew = isNew
        self.stickerConfirmedUS = stickerConfirmedUS
        self.decodedAt = decodedAt
        self.loans = []
    }
}
