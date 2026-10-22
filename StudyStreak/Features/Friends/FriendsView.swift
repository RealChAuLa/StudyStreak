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
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar, .tabBar)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .largeTitle) {
                    Text("Friends").font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let profile = session.profile {
                    NavigationLink {
                        AddFriendsView(userID: profile.uid, username: profile.username)
                    } label: {
                        Text("+ Add Friend")
                            .font(AppTypography.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.primary)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Add friend")
                }
            }
        }
    }
}
