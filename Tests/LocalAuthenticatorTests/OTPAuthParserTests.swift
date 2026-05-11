import XCTest
@testable import LocalAuthenticator

final class OTPAuthParserTests: XCTestCase {
    func testParsesCompleteTOTPURI() throws {
        let uri = "otpauth://totp/Example%20Corp:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example%20Corp&algorithm=SHA256&digits=8&period=60"

        let account = try OTPAuthParser.parse(uri)

        XCTAssertEqual(account.issuer, "Example Corp")
        XCTAssertEqual(account.accountName, "alice@example.com")
        XCTAssertEqual(account.secretBase32, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(account.algorithm, .sha256)
        XCTAssertEqual(account.digits, 8)
        XCTAssertEqual(account.period, 60)
    }

    func testUsesIssuerFromQueryWhenPresent() throws {
        let uri = "otpauth://totp/LabelIssuer:alice?secret=JBSWY3DPEHPK3PXP&issuer=QueryIssuer"

        let account = try OTPAuthParser.parse(uri)

        XCTAssertEqual(account.issuer, "QueryIssuer")
        XCTAssertEqual(account.accountName, "alice")
    }

    func testUsesIssuerAndAccountFromLabel() throws {
        let uri = "otpauth://totp/LabelIssuer:bob@example.com?secret=JBSWY3DPEHPK3PXP"

        let account = try OTPAuthParser.parse(uri)

        XCTAssertEqual(account.issuer, "LabelIssuer")
        XCTAssertEqual(account.accountName, "bob@example.com")
    }

    func testRejectsUnsupportedType() {
        let uri = "otpauth://hotp/Example:alice?secret=JBSWY3DPEHPK3PXP&counter=1"

        XCTAssertThrowsError(try OTPAuthParser.parse(uri)) { error in
            guard case OTPAuthParserError.unsupportedType = error else {
                return XCTFail("Expected unsupportedType, got \(error)")
            }
        }
    }

    func testRejectsMissingSecret() {
        let uri = "otpauth://totp/Example:alice?issuer=Example"

        XCTAssertThrowsError(try OTPAuthParser.parse(uri)) { error in
            guard case OTPAuthParserError.missingSecret = error else {
                return XCTFail("Expected missingSecret, got \(error)")
            }
        }
    }

    func testRejectsUnsupportedAlgorithm() {
        let uri = "otpauth://totp/Example:alice?secret=JBSWY3DPEHPK3PXP&algorithm=MD5"

        XCTAssertThrowsError(try OTPAuthParser.parse(uri)) { error in
            guard case OTPAuthParserError.unsupportedAlgorithm(let algorithm) = error else {
                return XCTFail("Expected unsupportedAlgorithm, got \(error)")
            }

            XCTAssertEqual(algorithm, "MD5")
        }
    }

    func testDoesNotDoubleDecodePercentEncodedValues() throws {
        let uri = "otpauth://totp/Example%2520Corp:alice?secret=JBSWY3DPEHPK3PXP&issuer=Example%2520Corp"

        let account = try OTPAuthParser.parse(uri)

        XCTAssertEqual(account.issuer, "Example%20Corp")
        XCTAssertEqual(account.accountName, "alice")
    }
}
