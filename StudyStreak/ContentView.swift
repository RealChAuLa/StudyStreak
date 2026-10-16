//
//  ContentView.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            Text("StudyStreak")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColors.text)
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
