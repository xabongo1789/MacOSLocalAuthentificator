import XCTest
@testable import LocalAuthenticator

final class Base32Tests: XCTestCase {
    func testDecodesValidSecret() throws {
        let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
        let data = try Base32.decode(secret)

        XCTAssertEqual(String(data: data, encoding: .utf8), "12345678901234567890")
    }

    func testDecodesSecretWithSpacesHyphensAndPadding() throws {
        let secret = "GEZD GNBV-GY3T QOJQ GEZD-GNBV GY3T QOJQ===="
        let data = try Base32.decode(secret)

        XCTAssertEqual(String(data: data, encoding: .utf8), "12345678901234567890")
    }

    func testRejectsEmptySecret() {
        XCTAssertThrowsError(try Base32.decode("  -  ===  ")) { error in
            guard case Base32Error.emptySecret = error else {
                return XCTFail("Expected emptySecret, got \(error)")
            }
        }
    }

    func testRejectsInvalidCharacter() {
        XCTAssertThrowsError(try Base32.decode("ABC0")) { error in
            guard case Base32Error.invalidCharacter(let character) = error else {
                return XCTFail("Expected invalidCharacter, got \(error)")
            }

            XCTAssertEqual(character, "0")
        }
    }

    func testRejectsInvalidFinalQuantumLength() {
        XCTAssertThrowsError(try Base32.decode("A")) { error in
            guard case Base32Error.invalidPadding = error else {
                return XCTFail("Expected invalidPadding, got \(error)")
            }
        }
    }

    func testRejectsNonZeroTrailingBits() {
        XCTAssertThrowsError(try Base32.decode("MZ")) { error in
            guard case Base32Error.invalidPadding = error else {
                return XCTFail("Expected invalidPadding, got \(error)")
            }
        }
    }
}
