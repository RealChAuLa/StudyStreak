//
//  ContentView.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            if hasCompletedOnboarding {
                VStack(spacing: 24) {
                    Text("StudyStreak")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.text)

                    #if DEBUG
                    Button("Replay introduction") {
                        hasCompletedOnboarding = false
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.primary)
                    .frame(minHeight: 44)
                    #endif
                }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
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
