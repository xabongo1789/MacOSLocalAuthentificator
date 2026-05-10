import SwiftUI

struct AddAccountView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: AddMode = .qr
    @State private var issuer = ""
    @State private var accountName = ""
    @State private var secretBase32 = ""
    @State private var algorithm: OTPAlgorithm = .sha1
    @State private var digits = 6
    @State private var period = 30
    @State private var localError: String?
    @State private var didAttemptManualAdd = false
    @State private var scannerResetID = UUID()

    enum AddMode: String, CaseIterable, Identifiable {
        case qr = "QR code"
        case manual = "Manuel"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ajouter un compte")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Scannez une URI otpauth://totp ou saisissez la clé manuellement.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Fermer")
                .keyboardShortcut(.cancelAction)
            }

            Picker("Mode", selection: $selectedMode) {
                ForEach(AddMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedMode == .qr {
                qrPane
            } else {
                manualPane
            }

            if let localError {
                InlineErrorView(message: localError)
            }

            Spacer()
        }
        .padding(24)
        .onChange(of: selectedMode) { _ in
            localError = nil
        }
    }

    private var qrPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            QRScannerView { rawCode in
                handleScannedCode(rawCode)
            }
            .id(scannerResetID)
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
            )

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.secondary)

                Text("Présentez le QR code TOTP devant la webcam. Le compte est ajouté dès que le code est reconnu et validé.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Service") {
                    TextField("Ex. GitHub", text: $issuer)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Compte") {
                    TextField("Ex. maxime@example.com", text: $accountName)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Clé Base32") {
                    TextField("JBSWY3DPEHPK3PXP", text: $secretBase32)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Algorithme") {
                    Picker("Algorithme", selection: $algorithm) {
                        ForEach(OTPAlgorithm.allCases) { algorithm in
                            Text(algorithm.rawValue).tag(algorithm)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                LabeledContent("Chiffres") {
                    Picker("Chiffres", selection: $digits) {
                        Text("6").tag(6)
                        Text("7").tag(7)
                        Text("8").tag(8)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                LabeledContent("Période") {
                    Picker("Période", selection: $period) {
                        Text("15 s").tag(15)
                        Text("30 s").tag(30)
                        Text("60 s").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .labeledContentStyle(.manualForm)

            if let previewAccount = manualPreviewAccount {
                ManualPreviewView(account: previewAccount)
            } else if didAttemptManualAdd, let manualValidationMessage {
                InlineErrorView(message: manualValidationMessage)
            }

            HStack(spacing: 12) {
                Spacer()

                Button("Annuler") {
                    dismiss()
                }

                Button {
                    addManualAccount()
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
                .disabled(manualPreviewAccount == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var manualPreviewAccount: OTPAccount? {
        try? AccountValidator.makeManualAccount(
            issuer: issuer,
            accountName: accountName,
            secretBase32: secretBase32,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }

    private var manualValidationMessage: String? {
        do {
            _ = try AccountValidator.makeManualAccount(
                issuer: issuer,
                accountName: accountName,
                secretBase32: secretBase32,
                algorithm: algorithm,
                digits: digits,
                period: period
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func addManualAccount() {
        didAttemptManualAdd = true

        do {
            let account = try AccountValidator.makeManualAccount(
                issuer: issuer,
                accountName: accountName,
                secretBase32: secretBase32,
                algorithm: algorithm,
                digits: digits,
                period: period
            )
            accountStore.add(account)

            if accountStore.lastError == nil {
                dismiss()
            } else {
                localError = accountStore.lastError
            }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func handleScannedCode(_ rawCode: String) {
        do {
            let account = try AccountValidator.parseOTPAuthURI(rawCode)
            accountStore.add(account)

            if accountStore.lastError == nil {
                dismiss()
            } else {
                localError = accountStore.lastError
                scannerResetID = UUID()
            }
        } catch {
            localError = error.localizedDescription
            scannerResetID = UUID()
        }
    }
}

private struct ManualPreviewView: View {
    let account: OTPAccount

    var body: some View {
        HStack(spacing: 12) {
            AccountAvatarView(account: account, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prêt à ajouter")
                    .font(.headline)

                Text("\(account.issuer) • \(account.accountName)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(account.algorithm.rawValue) · \(account.digits) chiffres · \(account.period) s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.green.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct InlineErrorView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ManualFormLabelStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            configuration.label
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            configuration.content
        }
    }
}

private extension LabeledContentStyle where Self == ManualFormLabelStyle {
    static var manualForm: ManualFormLabelStyle {
        ManualFormLabelStyle()
    }
}
