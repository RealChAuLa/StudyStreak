//
//  ContentView.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasReviewedLocationPermission") private var hasReviewedLocationPermission = false
    @AppStorage("hasCompletedPermissionSetup") private var hasCompletedPermissionSetup = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

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
                AuthenticationView(onReplaySetup: {
                    hasCompletedPermissionSetup = false
                    hasReviewedLocationPermission = false
                    hasCompletedOnboarding = false
                })
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: setupStep)
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
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}
