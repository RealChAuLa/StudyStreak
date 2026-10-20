//
//  ContentView.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppSession.self) private var session
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasReviewedLocationPermission") private var hasReviewedLocationPermission = false
    @AppStorage("hasCompletedPermissionSetup") private var hasCompletedPermissionSetup = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recoveryError: String?

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            switch session.phase {
            case .loading:
                ProgressView("Opening StudyStreak…")
                    .font(AppTypography.body)
                    .tint(AppColors.primary)
            case .signedOut:
                signedOutContent
            case .accountSetup:
                AccountSetupView()
                    .id(session.uid)
            case .home:
                if let profile = session.profile {
                    MainTabView(username: profile.username)
                        .id(profile.uid)
                }
            case .profileError:
                accountRecovery
            case .notConfigured:
                ContentUnavailableView("Unable to Start StudyStreak", systemImage: "exclamationmark.triangle", description: Text("something went wrong, please try again"))
            }
        }
        .foregroundStyle(AppColors.text)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: setupStep)
    }

    @ViewBuilder
    private var signedOutContent: some View {
        switch setupStep {
        case .introduction:
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .transition(.opacity)
        case .location:
            LocationPermissionView {
                hasReviewedLocationPermission = true
            }
            .transition(.opacity)
        case .notifications:
            NotificationPermissionView {
                hasCompletedPermissionSetup = true
            }
            .transition(.opacity)
        case .authentication:
            AuthenticationView(initialMode: session.preferredAuthenticationMode, onReplaySetup: {
                hasCompletedPermissionSetup = false
                hasReviewedLocationPermission = false
                hasCompletedOnboarding = false
            })
            .transition(.opacity)
        }
    }

    private var accountRecovery: some View {
        VStack(spacing: 24) {
            Text("Couldn’t load your profile")
                .font(AppTypography.title2)
            Text(session.profileErrorMessage)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondary)
            PrimaryButton(title: "Try again") { session.retryProfile() }
            Button("Log out") {
                do { try session.signOut() }
                catch { recoveryError = AccountError.message(for: error) }
            }
                .font(AppTypography.headline)
                .frame(minHeight: 44)
            if let recoveryError {
                Text(recoveryError).font(AppTypography.subheadline).foregroundStyle(AppColors.danger)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
    }

    private var setupStep: SetupStep {
        if !hasCompletedOnboarding { return .introduction }
        if !hasReviewedLocationPermission { return .location }
        if !hasCompletedPermissionSetup { return .notifications }
        return .authentication
    }

    private enum SetupStep: Equatable {
        case introduction
        case location
        case notifications
        case authentication
    }
}

#Preview("Light") {
    ContentView()
        .environment(AppSession())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .environment(AppSession())
        .preferredColorScheme(.dark)
}
