import SwiftUI

struct UsernameView: View {
    let onContinue: () -> Void
    @Environment(AppSession.self) private var session
    @State private var username = ""
    @State private var availability: Availability = .idle
    @State private var retryCount = 0
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 24) {
                    Text("What should\nwe call you?")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("This is how friends will find you.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("USERNAME")
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondary)
                        AuthenticationInput(isFocused: isFocused, hasError: availability == .taken) {
                            TextField("Username", text: $username, prompt: Text("devinda.studies").foregroundStyle(AppColors.secondary))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .keyboardType(.asciiCapable)
                                .submitLabel(.continue)
                                .focused($isFocused)
                                .onSubmit(continueSetup)
                                .accessibilityLabel("Username")
                            availabilityIcon
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                        }
                    }
                    status
                    Text("3–20 characters. Letters, numbers, dots and underscores.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                    if let saveError {
                        Text(saveError)
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.danger)
                    }
                }
                .padding(.top, 8)
            }
            .disabled(isSaving)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: isSaving ? "Saving…" : "Continue", action: continueSetup)
                .disabled(!canContinue)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .background(AppColors.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Make it yours").font(AppTypography.headline).foregroundStyle(AppColors.text)
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    do { try session.signOut() }
                    catch { saveError = AccountError.message(for: error) }
                } label: { Image(systemName: "chevron.backward") }
                .accessibilityLabel("Back to sign in")
                .disabled(isSaving)
            }
        }
        .onAppear {
            if username.isEmpty { username = session.profile?.username ?? "" }
        }
        .onChange(of: username) { _, _ in
            availability = .idle
            saveError = nil
        }
        .task(id: "\(username)#\(retryCount)") { await checkAvailability() }
    }

    private var canContinue: Bool { availability == .available && UsernameRules.isValid(username) && !isSaving }

    @ViewBuilder private var availabilityIcon: some View {
        switch availability {
        case .available:
            Image("SetupCheck").resizable().scaledToFit().foregroundStyle(AppColors.success)
        case .taken:
            Image(systemName: "xmark").foregroundStyle(AppColors.danger)
        case .checking: ProgressView().tint(AppColors.primary)
        default: EmptyView()
        }
    }

    @ViewBuilder private var status: some View {
        switch availability {
        case .available:
            statusText("\(UsernameRules.canonical(username)) is available", color: AppColors.successText)
        case .taken:
            statusText("That username is taken. Try another.", color: AppColors.danger)
        case .checking:
            statusText("Checking availability…", color: AppColors.secondary)
        case .failed:
            VStack(alignment: .leading, spacing: 4) {
                statusText("Couldn’t check availability. Check your connection.", color: AppColors.danger)
                Button("Try again") { retryCount += 1 }
                    .font(AppTypography.subheadline)
                    .frame(minHeight: 44)
            }
        case .idle:
            if !username.isEmpty && !UsernameRules.isValid(username) {
                statusText("Use 3–20 letters, numbers, dots or underscores.", color: AppColors.secondary)
            }
        }
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text).font(AppTypography.subheadline).foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func checkAvailability() async {
        let name = UsernameRules.canonical(username)
        guard UsernameRules.isValid(name) else { availability = .idle; return }
        availability = .checking
        do {
            try await Task.sleep(for: .milliseconds(350))
            let available = try await session.isUsernameAvailable(name)
            try Task.checkCancellation()
            guard name == UsernameRules.canonical(username) else { return }
            availability = available ? .available : .taken
        } catch is CancellationError { }
        catch {
            guard !Task.isCancelled else { return }
            availability = .failed
        }
    }

    private func continueSetup() {
        guard canContinue else { return }
        isFocused = false
        isSaving = true
        saveError = nil
        let name = UsernameRules.canonical(username)
        Task {
            defer { isSaving = false }
            do {
                try await session.reserveUsername(name)
                username = name
                onContinue()
            } catch {
                saveError = AccountError.message(for: error)
                availability = .idle
                retryCount += 1
            }
        }
    }

    private enum Availability: Equatable { case idle, checking, available, taken, failed }
}

#Preview("06 · Username") {
    NavigationStack { UsernameView { } }
        .environment(AppSession())
}

#Preview("Username · Dark") {
    NavigationStack { UsernameView { } }
        .environment(AppSession())
        .preferredColorScheme(.dark)
}
