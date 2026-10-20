import Foundation
import SwiftUI

struct HomeView: View {
    let username: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting(at: context.date)),")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                Text(username)
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func greeting(at date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}

#Preview("Home") {
    NavigationStack { HomeView(username: "devinda.studies") }
}

#Preview("Home · Dark") {
    NavigationStack { HomeView(username: "devinda.studies") }
        .preferredColorScheme(.dark)
}
