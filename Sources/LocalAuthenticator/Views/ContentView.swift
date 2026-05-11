import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @State private var showingAddAccount = false
    @State private var searchText = ""
    @State private var selectedAccountID: OTPAccount.ID?
    @State private var accountPendingDeletion: OTPAccount?

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
                    deleteAccount(selectedAccount)
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
        .alert("Supprimer ce compte ?", isPresented: deleteConfirmationBinding) {
            Button("Annuler", role: .cancel) {
                accountPendingDeletion = nil
            }
            Button("Supprimer", role: .destructive) {
                guard let account = accountPendingDeletion else {
                    return
                }

                deleteAccount(account)
                accountPendingDeletion = nil
            }
        } message: {
            Text("Le secret sera supprimé du Keychain local.")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Authenticator")
                        .font(.title3)
                        .fontWeight(.semibold)

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
                .buttonStyle(.liquidGlassIcon)
            }
            .padding([.horizontal, .top], 18)
            .padding(.bottom, 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Rechercher", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidGlassCapsule(material: .thinMaterial)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            Rectangle()
                .fill(.white.opacity(0.22))
                .frame(height: 1)
                .padding(.horizontal, 18)

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
                                    accountPendingDeletion = account
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.clear)
            }

            if let error = accountStore.lastError {
                ErrorBannerView(message: error)
                    .padding(12)
            }
        }
        .background {
            LiquidGlassBackdrop()
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            accountPendingDeletion != nil
        } set: { isPresented in
            if !isPresented {
                accountPendingDeletion = nil
            }
        }
    }

    private func deleteAccount(_ account: OTPAccount) {
        accountStore.delete(account)

        if selectedAccountID == account.id {
            selectedAccountID = nil
        }

        selectFallbackAccount()
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
        ZStack {
            LiquidGlassBackdrop()

            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    AccountAvatarView(account: account, size: 56)

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
                    .buttonStyle(.liquidGlassProminent)

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Supprimer ce compte")
                    .buttonStyle(.liquidGlassIcon)
                }
                .padding(20)
                .liquidGlassPanel(cornerRadius: 24, material: .thinMaterial, shadowRadius: 12, shadowOpacity: 0.10)

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
                .liquidGlassPanel(cornerRadius: 30, material: .regularMaterial, shadowRadius: 22, shadowOpacity: 0.13)
            }
            .padding(22)
        }
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
        ClipboardCodeCopier.copy(code)
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
        .liquidGlassPanel(cornerRadius: 16, material: .thinMaterial, shadowRadius: 8, shadowOpacity: 0.06)
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
            .buttonStyle(.liquidGlassProminent)
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
            .buttonStyle(.liquidGlassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            LiquidGlassBackdrop()
        }
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
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.red.opacity(0.18), lineWidth: 1)
        }
    }
}
