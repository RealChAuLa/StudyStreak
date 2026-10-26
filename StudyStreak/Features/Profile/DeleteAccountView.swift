import SwiftData
import SwiftUI

struct DeleteAccountView: View {
    var isRecovery = false
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var method: AccountDeletionMethod = .password
    @State private var password = ""
    @State private var understandsDeletion = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                introduction
                if session.isDeletingAccount {
                    Section {
                        ProgressView(session.deletionStatus)
                            .font(AppTypography.body).frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .listRowBackground(AppColors.surface)
                } else {
                    verification
                    confirmation
                    if let error = errorMessage ?? session.deletionErrorMessage {
                        Section {
                            Text(error).font(AppTypography.subheadline).foregroundStyle(AppColors.danger)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(AppColors.surface)
                    }
                    deletionButton
                    if isRecovery || session.hasPendingDeletion { signOutButton }
                }
            }
            .font(AppTypography.body).foregroundStyle(AppColors.text)
            .scrollContentBackground(.hidden).scrollIndicators(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Delete account").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isRecovery && !session.hasPendingDeletion {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.disabled(session.isDeletingAccount)
                    }
                }
            }
            .interactiveDismissDisabled(session.isDeletingAccount || session.hasPendingDeletion)
            .onAppear {
                if !session.deletionMethods.contains(method) { method = session.deletionMethods.first ?? .password }
                if isRecovery || session.hasPendingDeletion { understandsDeletion = true }
            }
        }
    }

    private var introduction: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.hasPendingDeletion ? "Finish deleting your account" : "Your account, your choice.")
                    .font(AppTypography.title2).foregroundStyle(AppColors.text)
                Text("This permanently removes your profile, photo, username, friendships, study totals, and the study data saved on this device.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondary)
                Text("We’ll verify your sign-in, then ask for Face ID, Touch ID, or your device passcode.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            }
            .fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
        }
        .listRowBackground(AppColors.surface)
    }

    private var verification: some View {
        Section("Verify your account") {
            if session.deletionMethods.count > 1 {
                Picker("Sign-in method", selection: $method) {
                    ForEach(session.deletionMethods) { value in Text(value.title).tag(value) }
                }
                .pickerStyle(.menu)
            }
            if session.deletionMethods.isEmpty {
                Text("Please sign out and sign in again to verify your account.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            } else if method == .password {
                SecureField("Current password", text: $password)
                    .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
            } else {
                Label("Continue with Google to verify your account.", systemImage: "person.crop.circle.badge.checkmark")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            }
        }
        .listRowBackground(AppColors.surface)
    }

    private var confirmation: some View {
        Section {
            Toggle("I understand that deleting my account is permanent.", isOn: $understandsDeletion)
                .tint(AppColors.primary).fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(AppColors.surface)
    }

    private var deletionButton: some View {
        Section {
            Button(role: .destructive, action: removeAccount) {
                Text(session.hasPendingDeletion ? "Finish Deleting Account" : "Delete Account")
                    .font(AppTypography.headline).foregroundStyle(AppColors.danger)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .disabled(!understandsDeletion || session.deletionMethods.isEmpty
                      || (method == .password && password.isEmpty))
        }
        .listRowBackground(AppColors.surface)
    }

    private var signOutButton: some View {
        Section {
            Button("Sign Out") {
                do { try session.signOut() }
                catch { errorMessage = AccountDeletionRepository.message(for: error) }
            }
            .font(AppTypography.headline).foregroundStyle(AppColors.primary).frame(minHeight: 44)
            Text("You can sign in again to finish an interrupted deletion.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
        }
        .listRowBackground(AppColors.surface)
    }

    private func removeAccount() {
        errorMessage = nil
        let credential = password
        password = ""
        Task {
            do {
                try await session.deleteAccount(method: method, password: credential, in: modelContext.container)
                dismiss()
            } catch is CancellationError {
                // Cancelling verification leaves the account unchanged.
            } catch {
                errorMessage = AccountDeletionRepository.message(for: error)
            }
        }
    }
}
