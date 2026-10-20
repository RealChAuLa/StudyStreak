import SwiftUI

struct HomeView: View {
    let username: String
    @Environment(AppSession.self) private var session
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text(username)
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.text)
                .accessibilityLabel("Your username is \(username)")
            PrimaryButton(title: "Log out") {
                do { try session.signOut() }
                catch { errorMessage = AccountError.message(for: error) }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.danger)
            }
        }
        .padding(24)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
    }
}
