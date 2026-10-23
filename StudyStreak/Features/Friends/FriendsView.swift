import SwiftUI

struct FriendsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        // The leaderboard will be added in the next Friends milestone.
        ScrollView {
            Text("A little company helps.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            if let profile = session.profile {
                NavigationLink {
                    AddFriendsView(
                        userID: profile.uid,
                        username: profile.username
                    )
                } label: {
                    Image("ZoneListAddFloating")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(AppColors.onPrimary)
                        .frame(width: 56, height: 56)
                        .background(AppColors.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add friend")
                .padding(.trailing, 32)
                .padding(.bottom, 16)
            }
        }
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar, .tabBar)
    }
}
