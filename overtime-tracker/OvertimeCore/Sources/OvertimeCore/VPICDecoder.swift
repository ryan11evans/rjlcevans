import Foundation

/// Parses a NHTSA vPIC `DecodeVinValues` JSON payload. No network.
public enum VPICDecoder {
    public struct Decoded: Equatable, Sendable {
        public var make: String?
        public var model: String?
        public var modelYear: Int?
        public var plantCountry: String?
        public var gvwrText: String?
        /// Pounds used for the 14,000 lb test. Nil when vPIC gave no figure or a class range
        /// that crosses 14,000 lb (the caller should ask the user).
        public var gvwrPounds: Int?
        public var vehicleType: VehicleType
        public var assembly: AssemblySignal
        public var errorText: String?

        public init(make: String?, model: String?, modelYear: Int?, plantCountry: String?, gvwrText: String?,
                    gvwrPounds: Int?, vehicleType: VehicleType, assembly: AssemblySignal, errorText: String?) {
            self.make = make
            self.model = model
            self.modelYear = modelYear
            self.plantCountry = plantCountry
            self.gvwrText = gvwrText
            self.gvwrPounds = gvwrPounds
            self.vehicleType = vehicleType
            self.assembly = assembly
            self.errorText = errorText
        }
    }

    public enum DecodeError: Error, Equatable {
        case unreadable
        case noResults
    }

    public static func decode(json: Data) throws -> Decoded {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: json)
        } catch {
            throw DecodeError.unreadable
        }
        guard let row = payload.Results.first else { throw DecodeError.noResults }
        let country = blankToNil(row.PlantCountry)
        let gvwrText = blankToNil(row.GVWR)
        return Decoded(
            make: blankToNil(row.Make),
            model: blankToNil(row.Model),
            modelYear: blankToNil(row.ModelYear).flatMap { Int($0) },
            plantCountry: country,
            gvwrText: gvwrText,
            gvwrPounds: gvwrPounds(from: gvwrText),
            vehicleType: vehicleType(vehicleType: row.VehicleType, bodyClass: row.BodyClass),
            assembly: assemblySignal(plantCountry: country),
            errorText: blankToNil(row.ErrorText)
        )
    }

    /// `PlantCountry` of "UNITED STATES" (any parenthetical) is US final assembly.
    /// A blank field is unknown. Anything else is not a US plant.
    public static func assemblySignal(plantCountry: String?) -> AssemblySignal {
        guard let trimmed = blankToNil(plantCountry) else { return .unknown }
        let upper = trimmed.uppercased()
        if upper.contains("UNITED STATES") || upper == "USA" || upper == "US" {
            return .usPlant
        }
        return .nonUSPlant
    }

    /// Reads the pound range after the class label.
    /// A range that sits entirely under 14,000 lb returns its upper bound.
    /// A range that starts at 14,000 lb or more returns its lower bound.
    /// A range that crosses 14,000 lb returns nil.
    public static func gvwrPounds(from raw: String?) -> Int? {
        guard var body = blankToNil(raw) else { return nil }
        if let kg = body.range(of: "(", options: .backwards) {
            body = String(body[..<kg.lowerBound])
        }
        if let colon = body.firstIndex(of: ":") {
            body = String(body[body.index(after: colon)...])
        }
        let numbers = integers(in: body)
        guard let lower = numbers.first else { return nil }
        let upper = numbers.dropFirst().first ?? lower
        if lower >= 14_000 { return lower }
        if upper < 14_000 { return upper }
        return nil
    }

    public static func vehicleType(vehicleType: String?, bodyClass: String?) -> VehicleType {
        let body = (bodyClass ?? "").uppercased()
        if body.contains("MINIVAN") { return .minivan }
        if body.contains("SPORT UTILITY") || body.contains("SUV") { return .suv }
        if body.contains("PICKUP") { return .pickup }
        if body.contains("MOTORCYCLE") { return .motorcycle }
        if body.contains("VAN") { return .van }
        let kind = (vehicleType ?? "").uppercased()
        if kind.contains("MOTORCYCLE") { return .motorcycle }
        if kind.contains("TRUCK") { return .pickup }
        if kind.contains("MULTIPURPOSE") { return .suv }
        if kind.contains("PASSENGER CAR") { return .car }
        if kind.contains("VAN") { return .van }
        return .other
    }

    private static func blankToNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func integers(in text: String) -> [Int] {
        var numbers: [Int] = []
        var current = ""
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if character == "," && !current.isEmpty {
                continue
            } else if !current.isEmpty {
                if let value = Int(current) { numbers.append(value) }
                current = ""
            }
        }
        if let value = Int(current) { numbers.append(value) }
        return numbers
    }

    private struct Payload: Decodable {
        var Results: [Row]
    }

    private struct Row: Decodable {
        var Make: String?
        var Model: String?
        var ModelYear: String?
        var PlantCountry: String?
        var GVWR: String?
        var VehicleType: String?
        var BodyClass: String?
        var ErrorText: String?
    }
}
