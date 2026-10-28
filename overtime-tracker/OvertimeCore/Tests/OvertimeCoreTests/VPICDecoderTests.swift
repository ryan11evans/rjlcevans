import XCTest
import OvertimeCore

final class VPICDecoderTests: XCTestCase {
    func testUnitedStatesPlant() throws {
        let decoded = try VPICDecoder.decode(json: Data(fixture(
            plant: "UNITED STATES (USA)",
            gvwr: "Class 1C: 4,001 - 5,000 lb (1,814 - 2,268 kg)",
            vehicleType: "PASSENGER CAR",
            body: "Sedan/Saloon"
        ).utf8))
        XCTAssertEqual(decoded.assembly, .usPlant)
        XCTAssertEqual(decoded.make, "HONDA")
        XCTAssertEqual(decoded.modelYear, 2026)
        XCTAssertEqual(decoded.gvwrPounds, 5_000)
        XCTAssertEqual(decoded.vehicleType, .car)
    }

    func testNonUSPlantIsNotEligibleSignal() {
        XCTAssertEqual(VPICDecoder.assemblySignal(plantCountry: "MEXICO"), .nonUSPlant)
        XCTAssertEqual(VPICDecoder.assemblySignal(plantCountry: "CANADA"), .nonUSPlant)
    }

    func testBlankPlantIsUnknown() throws {
        let decoded = try VPICDecoder.decode(json: Data(fixture(plant: "", gvwr: "", vehicleType: "", body: "").utf8))
        XCTAssertEqual(decoded.assembly, .unknown)
        XCTAssertNil(decoded.plantCountry)
        XCTAssertNil(decoded.gvwrPounds)
        XCTAssertEqual(decoded.vehicleType, .other)
    }

    func testGVWRRanges() {
        XCTAssertEqual(VPICDecoder.gvwrPounds(from: "Class 2E: 6,001 - 7,000 lb (2,722 - 3,175 kg)"), 7_000)
        XCTAssertNil(VPICDecoder.gvwrPounds(from: "Class 3: 10,001 - 14,000 lb (4,536 - 6,350 kg)"))
        XCTAssertEqual(VPICDecoder.gvwrPounds(from: "Class 8: 33,001 lb and above (14,969 kg and above)"), 33_001)
        XCTAssertNil(VPICDecoder.gvwrPounds(from: ""))
    }

    func testBodyClassMapping() {
        XCTAssertEqual(VPICDecoder.vehicleType(vehicleType: "TRUCK", bodyClass: "Pickup"), .pickup)
        XCTAssertEqual(VPICDecoder.vehicleType(vehicleType: "MULTIPURPOSE PASSENGER VEHICLE (MPV)", bodyClass: "Sport Utility Vehicle (SUV)/Multi-Purpose Vehicle (MPV)"), .suv)
        XCTAssertEqual(VPICDecoder.vehicleType(vehicleType: "MULTIPURPOSE PASSENGER VEHICLE (MPV)", bodyClass: "Minivan"), .minivan)
        XCTAssertEqual(VPICDecoder.vehicleType(vehicleType: "MOTORCYCLE", bodyClass: ""), .motorcycle)
        XCTAssertEqual(VPICDecoder.vehicleType(vehicleType: "TRAILER", bodyClass: "Trailer"), .other)
    }

    func testUnreadableJSON() {
        XCTAssertThrowsError(try VPICDecoder.decode(json: Data("[]".utf8))) { error in
            XCTAssertEqual(error as? VPICDecoder.DecodeError, .unreadable)
        }
    }

    private func fixture(plant: String, gvwr: String, vehicleType: String, body: String) -> String {
        """
        {"Count":1,"Message":"Results returned successfully","Results":[{
          "Make":"HONDA","Model":"Civic","ModelYear":"2026",
          "PlantCountry":"\(plant)","GVWR":"\(gvwr)",
          "VehicleType":"\(vehicleType)","BodyClass":"\(body)","ErrorText":""
        }]}
        """
    }
}
