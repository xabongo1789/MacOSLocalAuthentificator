import XCTest
@testable import LocalAuthenticator

final class TOTPGeneratorTests: XCTestCase {
    private let sha1Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    private let sha256Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA"
    private let sha512Secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA"

    func testGeneratesSHA1CodesFromRFC6238Vectors() throws {
        try assertVectors(
            secret: sha1Secret,
            algorithm: .sha1,
            expectedCodes: ["94287082", "07081804", "14050471", "89005924", "69279037", "65353130"]
        )
    }

    func testGeneratesSHA256CodesFromRFC6238Vectors() throws {
        try assertVectors(
            secret: sha256Secret,
            algorithm: .sha256,
            expectedCodes: ["46119246", "68084774", "67062674", "91819424", "90698825", "77737706"]
        )
    }

    func testGeneratesSHA512CodesFromRFC6238Vectors() throws {
        try assertVectors(
            secret: sha512Secret,
            algorithm: .sha512,
            expectedCodes: ["90693936", "25091201", "99943326", "93441116", "38618901", "47863826"]
        )
    }

    private func assertVectors(
        secret: String,
        algorithm: OTPAlgorithm,
        expectedCodes: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let timestamps: [TimeInterval] = [59, 1_111_111_109, 1_111_111_111, 1_234_567_890, 2_000_000_000, 20_000_000_000]

        for (timestamp, expectedCode) in zip(timestamps, expectedCodes) {
            let code = try TOTPGenerator.generate(
                secretBase32: secret,
                date: Date(timeIntervalSince1970: timestamp),
                period: 30,
                digits: 8,
                algorithm: algorithm
            )

            XCTAssertEqual(code, expectedCode, "Timestamp \(timestamp)", file: file, line: line)
        }
    }
}
