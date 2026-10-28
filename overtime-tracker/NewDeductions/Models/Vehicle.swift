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
        self.vehicleTypeRaw = vehicleTypeRaw
        self.assemblySignalRaw = assemblySignalRaw
        self.isNew = isNew
        self.stickerConfirmedUS = stickerConfirmedUS
        self.decodedAt = decodedAt
        self.loans = []
    }
}
