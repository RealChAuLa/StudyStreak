import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @State private var errorMessage: String?

    var body: some View {
        // TODO: Add the profile and settings content in a later milestone.
        AppColors.background
            .ignoresSafeArea()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log out") {
                        do { try session.signOut() }
                        catch { errorMessage = AccountError.message(for: error) }
                    }
                    .font(AppTypography.headline)
                }
            }
            .alert("Couldn’t log out", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
    }
}
