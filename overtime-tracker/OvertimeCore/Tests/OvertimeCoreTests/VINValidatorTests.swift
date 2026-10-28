import XCTest
import OvertimeCore

final class VINValidatorTests: XCTestCase {
    func testKnownCheckDigit() {
        XCTAssertEqual(VINValidator.status("1M8GDM9AXKP042788"), .valid)
        XCTAssertTrue(VINValidator.isValid("1m8gdm9axkp042788"))
        XCTAssertTrue(VINValidator.isValid("1M8GDM9A XKP042788"))
    }

    func testBadCheckDigit() {
        XCTAssertEqual(VINValidator.status("1M8GDM9A0KP042788"), .badCheckDigit(expected: "X"))
    }

    func testIllegalCharactersAndLength() {
        XCTAssertEqual(VINValidator.status("1M8GDM9AXKP04278"), .wrongLength(16))
        XCTAssertEqual(VINValidator.status("1M8GDM9IXKP042788"), .illegalCharacter("I"))
        XCTAssertEqual(VINValidator.status("1M8GDM9OXKP042788"), .illegalCharacter("O"))
        XCTAssertEqual(VINValidator.status("1M8GDM9QXKP042788"), .illegalCharacter("Q"))
    }
}
