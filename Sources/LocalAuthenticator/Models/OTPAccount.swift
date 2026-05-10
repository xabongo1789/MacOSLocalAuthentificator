import Foundation

struct OTPAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var issuer: String
    var accountName: String
    var secretBase32: String
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: Int

    init(
        id: UUID = UUID(),
        issuer: String,
        accountName: String,
        secretBase32: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: Int = 30
    ) {
        self.id = id
        self.issuer = issuer
        self.accountName = accountName
        self.secretBase32 = secretBase32
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }
}
