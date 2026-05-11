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
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
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

    private var seedColor: Color {
        let seed = account.issuer.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult + Int(scalar.value)) % 360
        }

        return Color(hue: Double(seed) / 360, saturation: 0.62, brightness: 0.92)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            seedColor.opacity(0.44),
                            seedColor.opacity(0.16)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size
                    )
                )

            Circle()
                .strokeBorder(.white.opacity(0.42), lineWidth: 1)

            Circle()
                .strokeBorder(seedColor.opacity(0.22), lineWidth: 2)

            Text(initials)
                .font(.system(size: max(12, size * 0.36), weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: size, height: size)
        .shadow(color: seedColor.opacity(0.18), radius: size * 0.18, x: 0, y: size * 0.08)
        .accessibilityHidden(true)
    }
}
