import Foundation
import SwiftUI
import UIKit

struct AuthenticationScreen: View {
    let mode: AuthenticationMode
    let onReplaySetup: (() -> Void)?
    let onSwitch: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var hasSubmitted = false
    @State private var previewAction: PreviewAction?
    @FocusState private var focusedField: Field?
    @ScaledMetric(relativeTo: .largeTitle) private var titleHeight: CGFloat = 82
    @ScaledMetric(relativeTo: .subheadline) private var messageHeight: CGFloat = 42

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction

                VStack(alignment: .leading, spacing: 16) {
                    emailField
                    passwordField
                }

                PrimaryButton(title: mode.buttonTitle, action: submit)

                HStack(spacing: 16) {
                    Rectangle().fill(AppColors.border).frame(height: 1)
                    Text("or")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize()
                    Rectangle().fill(AppColors.border).frame(height: 1)
                }
                .accessibilityHidden(true)

                GoogleAuthenticationButton {
                    focusedField = nil
                    previewAction = .google
                }

                switchButton
            }
            .frame(maxWidth: 430, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background.ignoresSafeArea())
        .alert(item: $previewAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("StudyStreak")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .frame(minHeight: 22, alignment: .leading)
                .contextMenu {
                    #if DEBUG
                    if let onReplaySetup {
                        Button("Replay setup", action: onReplaySetup)
                    }
                    #endif
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(mode.title)
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: titleHeight, alignment: .topLeading)
                    .accessibilityAddTraits(.isHeader)

                Text(mode.message)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: messageHeight, alignment: .topLeading)
            }
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email address")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.text)
                .frame(minHeight: 21)

            AuthenticationInput(isFocused: focusedField == .email, hasError: emailError != nil) {
                TextField(
                    "Email address",
                    text: $email,
                    prompt: Text("you@example.com").foregroundStyle(AppColors.secondary)
                )
                .keyboardType(.emailAddress)
                .textContentType(mode == .signUp ? .emailAddress : .username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .accessibilityLabel("Email address")
                .accessibilityHint(emailError ?? "")
            }

            if let emailError {
                errorMessage(emailError)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Password")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.text)
                Spacer()

                if mode == .signIn {
                    Button("Forgot password?") {
                        focusedField = nil
                        previewAction = .passwordReset
                    }
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.primary)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 21)

            AuthenticationInput(isFocused: focusedField == .password, hasError: passwordError != nil) {
                Group {
                    if isPasswordVisible {
                        TextField(
                            "Password",
                            text: $password,
                            prompt: Text(mode.passwordPlaceholder).foregroundStyle(AppColors.secondary)
                        )
                    } else {
                        SecureField(
                            "Password",
                            text: $password,
                            prompt: Text(mode.passwordPlaceholder).foregroundStyle(AppColors.secondary)
                        )
                    }
                }
                .textContentType(mode == .signUp ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit(submit)
                .privacySensitive()
                .accessibilityLabel("Password")
                .accessibilityHint(passwordError ?? "")

                Button(isPasswordVisible ? "Hide" : "Show") {
                    isPasswordVisible.toggle()
                    focusedField = .password
                }
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.primary)
                .frame(minWidth: 52, minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }

            if let passwordError {
                errorMessage(passwordError)
            } else if mode == .signUp {
                Text("Use at least 8 characters.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(minHeight: 16)
            }
        }
    }

    private var switchButton: some View {
        Button {
            focusedField = nil
            onSwitch()
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(mode.switchMessage).foregroundStyle(AppColors.secondary)
                    Text(mode.switchTitle).foregroundStyle(AppColors.primary)
                }
                VStack(spacing: 8) {
                    Text(mode.switchMessage).foregroundStyle(AppColors.secondary)
                    Text(mode.switchTitle).foregroundStyle(AppColors.primary)
                }
            }
            .font(AppTypography.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.switchMessage) \(mode.switchTitle)")
    }

    private var emailError: String? {
        guard hasSubmitted else { return nil }
        return emailValidationError
    }

    private var emailValidationError: String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "Enter your email address." }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return value.range(of: pattern, options: .regularExpression) == nil
            ? "Enter a valid email address." : nil
    }

    private var passwordError: String? {
        guard hasSubmitted else { return nil }
        if password.isEmpty { return "Enter your password." }
        if mode == .signUp && password.count < 8 { return "Use at least 8 characters." }
        return nil
    }

    private func errorMessage(_ message: String) -> some View {
        Text(message)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.danger)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func submit() {
        hasSubmitted = true
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if emailValidationError != nil {
            focusedField = .email
        } else if passwordError != nil {
            focusedField = .password
        } else {
            focusedField = nil
            previewAction = mode == .signUp ? .createAccount : .signIn
        }
    }

    private enum Field: Hashable {
        case email
        case password
    }

    private enum PreviewAction: String, Identifiable {
        case createAccount, signIn, google, passwordReset
        var id: String { rawValue }

        var title: String {
            switch self {
            case .createAccount: "Account creation preview"
            case .signIn: "Sign-in preview"
            case .google: "Google sign-in preview"
            case .passwordReset: "Password reset preview"
            }
        }

        var message: String {
            switch self {
            case .createAccount: "Account creation is not connected yet. No account has been created."
            case .signIn: "Sign-in is not connected yet. This screen is a preview."
            case .google: "Google sign-in is not connected yet. This screen is a preview."
            case .passwordReset: "Password reset is not connected yet. No reset email has been sent."
            }
        }
    }
}
