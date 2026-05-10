import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @State private var showingAddAccount = false
    @State private var searchText = ""
    @State private var selectedAccountID: OTPAccount.ID?

    private var filteredAccounts: [OTPAccount] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return accountStore.accounts
        }

        return accountStore.accounts.filter { account in
            account.issuer.localizedCaseInsensitiveContains(searchText) ||
            account.accountName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedAccount: OTPAccount? {
        guard let selectedAccountID else {
            return nil
        }

        return accountStore.accounts.first { $0.id == selectedAccountID }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            if let selectedAccount {
                AccountDetailView(account: selectedAccount) {
                    accountStore.delete(selectedAccount)
                    selectedAccountID = nil
                    selectFallbackAccount()
                }
                .id(selectedAccount.id)
            } else {
                EmptyAccountDetailView {
                    showingAddAccount = true
                }
            }
        }
        .onAppear(perform: selectFallbackAccount)
        .onChange(of: accountStore.accounts) { _ in
            selectFallbackAccount()
        }
        .onChange(of: searchText) { _ in
            selectFallbackAccount()
        }
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
                .environmentObject(accountStore)
                .frame(width: 680, height: 640)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Authenticator")
                        .font(.headline)

                    Text("\(accountStore.accounts.count) compte\(accountStore.accounts.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAddAccount = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Ajouter un compte")
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Rechercher", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            if accountStore.accounts.isEmpty {
                SidebarEmptyStateView {
                    showingAddAccount = true
                }
            } else if filteredAccounts.isEmpty {
                SearchEmptyStateView()
            } else {
                List(selection: $selectedAccountID) {
                    ForEach(filteredAccounts) { account in
                        AccountRowView(account: account)
                            .tag(account.id)
                            .contextMenu {
                                Button(role: .destructive) {
                                    accountStore.delete(account)
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }

            if let error = accountStore.lastError {
                ErrorBannerView(message: error)
                    .padding(12)
            }
        }
    }

    private func selectFallbackAccount() {
        if let selectedAccountID, filteredAccounts.contains(where: { $0.id == selectedAccountID }) {
            return
        }

        selectedAccountID = filteredAccounts.first?.id
    }
}

private struct AccountDetailView: View {
    let account: OTPAccount
    let onDelete: () -> Void

    @State private var code = "------"
    @State private var remaining = 30
    @State private var copied = false
    @State private var generationError: String?
    @State private var showingDeleteConfirmation = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                AccountAvatarView(account: account, size: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.issuer)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(account.accountName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    copyCode()
                } label: {
                    Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(generationError != nil)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .help("Supprimer ce compte")
            }
            .padding(28)

            Divider()

            VStack(spacing: 26) {
                VStack(spacing: 10) {
                    Text(formattedCode)
                        .font(.system(size: 62, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)

                    if let generationError {
                        Text(generationError)
                            .font(.callout)
                            .foregroundStyle(.red)
                    } else {
                        Text("Code valide encore \(remaining) s")
                            .font(.callout)
                            .foregroundStyle(remaining <= 5 ? .red : .secondary)
                    }
                }

                ProgressView(value: Double(remaining), total: Double(max(account.period, 1)))
                    .tint(remaining <= 5 ? .red : .accentColor)
                    .frame(maxWidth: 420)

                HStack(spacing: 12) {
                    DetailBadgeView(title: "Algorithme", value: account.algorithm.rawValue)
                    DetailBadgeView(title: "Chiffres", value: "\(account.digits)")
                    DetailBadgeView(title: "Période", value: "\(account.period) s")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in
            refresh()
        }
        .alert("Supprimer ce compte ?", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive, action: onDelete)
        } message: {
            Text("Le secret sera supprimé du Keychain local.")
        }
    }

    private var formattedCode: String {
        guard code.allSatisfy(\.isNumber) else {
            return code
        }

        let splitIndex = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[..<splitIndex]) \(code[splitIndex...])"
    }

    private func refresh() {
        let now = Date()
        let safePeriod = max(account.period, 1)
        let elapsed = Int(now.timeIntervalSince1970) % safePeriod
        remaining = safePeriod - elapsed

        do {
            code = try TOTPGenerator.generate(
                secretBase32: account.secretBase32,
                date: now,
                period: account.period,
                digits: account.digits,
                algorithm: account.algorithm
            )
            generationError = nil
        } catch {
            code = "Erreur"
            generationError = error.localizedDescription
        }
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            copied = false
        }
    }
}

private struct DetailBadgeView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(width: 110, height: 62)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SidebarEmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text("Aucun compte")
                .font(.headline)

            Text("Ajoutez un compte avec la webcam ou une clé manuelle.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)

            Button {
                onAdd()
            } label: {
                Label("Ajouter", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct SearchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)

            Text("Aucun résultat")
                .font(.headline)

            Text("Essayez un autre service ou compte.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct EmptyAccountDetailView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 62))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Codes TOTP stockés localement")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Les clés restent dans le Keychain macOS et ne sont pas synchronisées par cette app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 430)
            }

            Button {
                onAdd()
            } label: {
                Label("Ajouter un compte", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct ErrorBannerView: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
