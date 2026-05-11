import XCTest
@testable import LocalAuthenticator

final class AccountValidatorTests: XCTestCase {
    func testRejectsMalformedSingleCharacterSecret() {
        let account = OTPAccount(
            issuer: "Example",
            accountName: "alice",
            secretBase32: "A"
        )

        XCTAssertThrowsError(try AccountValidator.validate(account)) { error in
            guard case AccountValidationError.invalidSecret = error else {
                return XCTFail("Expected invalidSecret, got \(error)")
            }
        }
    }
}
