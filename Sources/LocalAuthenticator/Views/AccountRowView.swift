import SwiftUI

struct AccountRowView: View {
    let account: OTPAccount

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatarView(account: account, size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.issuer)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(account.accountName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(account.digits) chiffres")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct AccountAvatarView: View {
    let account: OTPAccount
    var size: CGFloat

    private var initials: String {
        let letters = account.issuer
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: max(12, size * 0.36), weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            )
    }
}
