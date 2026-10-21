import SwiftUI

struct EditProfileView: View {
    let profile: UserProfile
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var username: String
    @State private var photoData: Data?
    @State private var isProcessingPhoto = false
    @State private var isSaving = false
    @State private var availability: Availability = .idle
    @State private var retryCount = 0
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(profile: UserProfile) {
        self.profile = profile
        _displayName = State(initialValue: profile.displayName)
        _username = State(initialValue: profile.username)
        _photoData = State(initialValue: profile.photoData)
    }

    private var canonicalUsername: String { UsernameRules.canonical(username) }
    private var resolvedDisplayName: String { DisplayNameRules.resolved(displayName, username: canonicalUsername) }
    private var isBusy: Bool { isSaving || isProcessingPhoto }
    private var avatarInitial: String { canonicalUsername.isEmpty ? profile.initial : String(canonicalUsername.prefix(1)).uppercased() }
    private var hasChanges: Bool {
        canonicalUsername != profile.username || resolvedDisplayName != profile.displayName || photoData != profile.photoData
    }
    private var canSave: Bool {
        session.uid == profile.uid && !isBusy && hasChanges && DisplayNameRules.isValid(displayName) && UsernameRules.isValid(username)
            && (canonicalUsername == profile.username || availability == .available)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProfilePhotoEditor(initial: avatarInitial,
                                       photoData: $photoData, isProcessing: $isProcessingPhoto)
                    displayNameField
                    usernameField
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
                .disabled(isSaving)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).disabled(isBusy)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isSaving ? "Saving…" : "Save Changes", action: save)
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(AppColors.background)
            }
        }
        .tint(AppColors.primary)
        .interactiveDismissDisabled(isBusy)
        .onChange(of: username) { _, _ in availability = .idle }
        .task(id: "\(canonicalUsername)#\(retryCount)") { await checkAvailability() }
        .alert("Couldn’t save profile", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Display name")
            TextField("Display name", text: $displayName)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.text)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .displayName)
                .submitLabel(.next)
                .onSubmit { focusedField = .username }
                .padding(16)
                .frame(minHeight: 56)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Display name")
            Text(DisplayNameRules.isValid(displayName)
                 ? "Leave blank to use your username. Up to 50 characters."
                 : "Use 50 characters or fewer.")
                .font(AppTypography.caption)
                .foregroundStyle(DisplayNameRules.isValid(displayName) ? AppColors.secondary : AppColors.danger)
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Username")
            HStack(spacing: 12) {
                TextField("Username", text: $username)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .keyboardType(.asciiCapable)
                    .focused($focusedField, equals: .username)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .accessibilityLabel("Username")
                availabilityIcon.frame(width: 20, height: 20).accessibilityHidden(true)
            }
            .padding(16)
            .frame(minHeight: 56)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            usernameStatus
        }
    }

    @ViewBuilder private var availabilityIcon: some View {
        if canonicalUsername == profile.username || availability == .available {
            Image("EditProfileCheck").resizable().scaledToFit().foregroundStyle(AppColors.success)
        } else if availability == .checking {
            ProgressView().tint(AppColors.primary)
        } else if availability == .taken {
            Image(systemName: "xmark").foregroundStyle(AppColors.danger)
        }
    }

    @ViewBuilder private var usernameStatus: some View {
        if canonicalUsername == profile.username {
            statusText("This is your current username.", color: AppColors.secondary)
        } else if !UsernameRules.isValid(username) {
            statusText("Use 3–20 letters, numbers, dots or underscores.", color: AppColors.secondary)
        } else {
            switch availability {
            case .available: statusText("This username is available", color: AppColors.successText)
            case .taken: statusText("That username is taken. Try another.", color: AppColors.danger)
            case .checking: statusText("Checking availability…", color: AppColors.secondary)
            case .failed:
                statusText("Couldn’t check availability. Check your connection.", color: AppColors.danger)
                Button("Try again") { retryCount += 1 }.font(AppTypography.subheadline).frame(minHeight: 44)
            case .idle: statusText("Friends can find you using this username.", color: AppColors.secondary)
            }
        }
    }

    private func fieldLabel(_ value: String) -> some View {
        Text(value.uppercased()).font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.secondary)
    }

    private func statusText(_ value: String, color: Color) -> some View {
        Text(value).font(AppTypography.subheadline).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }

    private func checkAvailability() async {
        let name = canonicalUsername
        guard name != profile.username, UsernameRules.isValid(name) else { availability = .idle; return }
        availability = .checking
        do {
            try await Task.sleep(for: .milliseconds(350))
            let available = try await session.isUsernameAvailable(name)
            try Task.checkCancellation()
            guard name == canonicalUsername else { return }
            availability = available ? .available : .taken
        } catch is CancellationError { }
        catch { if !Task.isCancelled { availability = .failed } }
    }

    private func save() {
        guard canSave else { return }
        focusedField = nil
        isSaving = true
        let name = canonicalUsername
        let display = resolvedDisplayName
        let photo = photoData
        Task {
            defer { isSaving = false }
            do {
                try await session.updateProfile(for: profile.uid, username: name, displayName: display, photoData: photo)
                dismiss()
            } catch {
                errorMessage = AccountError.message(for: error)
                retryCount += 1
            }
        }
    }

    private enum Field: Hashable { case displayName, username }
    private enum Availability: Equatable { case idle, checking, available, taken, failed }
}

#Preview("30 · Edit profile") {
    EditProfileView(profile: UserProfile(uid: "preview", username: "devinda.studies", displayName: "Devinda",
                                         photoBase64: nil, setupCompleted: true))
        .environment(AppSession())
}
