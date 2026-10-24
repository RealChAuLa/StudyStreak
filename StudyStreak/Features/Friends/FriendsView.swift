import SwiftUI

struct FriendsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Group {
            if let profile = session.profile {
                FriendsContent(profile: profile).id(profile.uid)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

private struct FriendsContent: View {
    let profile: UserProfile
    @State private var model: LeaderboardModel
    @State private var period: LeaderboardPeriod = .thisWeek

    init(profile: UserProfile) {
        self.profile = profile
        _model = State(initialValue: LeaderboardModel(userID: profile.uid))
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            board(now: context.date)
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing) { addFriendButton }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private func board(now: Date) -> some View {
        List {
            heading.boardListRow(bottom: 24)
            periodPicker.boardListRow(bottom: 16)
            encouragement.boardListRow(bottom: 16)

            if let error = model.connectionError {
                messageCard(error, retry: true).boardListRow(bottom: 16)
            } else if model.isLoading || model.isLoadingFriends {
                ProgressView("Loading friends…")
                    .font(AppTypography.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .boardListRow(bottom: 16)
            }

            if let error = model.visibility.errorMessage {
                messageCard(error, retry: true).boardListRow(bottom: 16)
            } else if model.visibility.isLoaded && !model.visibility.isVisible {
                visibilityCard.boardListRow(bottom: 16)
            }

            ForEach(model.entries(ownProfile: profile, period: period, now: now)) { entry in
                LeaderboardRow(entry: entry).boardListRow(bottom: 8)
            }

            if !model.failedParts.isEmpty {
                messageCard("Some profiles or study totals couldn’t load.", retry: true)
                    .boardListRow(bottom: 16)
            }

            if !model.isLoading && !model.isLoadingFriends && model.connectionError == nil {
                if model.friendCount == 0 {
                    messageCard("A little company goes a long way. Tap + to find a friend.")
                        .boardListRow(bottom: 16)
                } else if model.visibleFriendCount == 0 && model.failedParts.isEmpty {
                    messageCard("Your friends haven’t shared their study totals yet.")
                        .boardListRow(bottom: 16)
                }
            }

            Text("Only friends can see your study time.\nYou choose whether to appear here.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .boardListRow(bottom: 16)
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            Text("A little company helps.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
        }
        .padding(.top, 8)
    }

    private var periodPicker: some View {
        Picker("Leaderboard period", selection: $period) {
            ForEach(LeaderboardPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 40)
    }

    private var encouragement: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep showing up, together.")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.text)
            Text("A shared rhythm. Your own pace.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.text.opacity(0.03), radius: 8, y: 3)
    }

    private var visibilityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your study time is private")
                .font(AppTypography.headline).foregroundStyle(AppColors.text)
            Text("Share your totals and streak with friends to join the rankings.")
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            Button {
                Task { await model.visibility.setVisible(true) }
            } label: {
                HStack(spacing: 8) {
                    if model.visibility.isSaving { ProgressView().tint(AppColors.primary) }
                    Text("Share with friends")
                }
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(model.visibility.isSaving)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func messageCard(_ text: String, retry: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if retry {
                Button("Try again") { model.start() }
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.primary)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private var addFriendButton: some View {
        NavigationLink {
            AddFriendsView(userID: profile.uid, username: profile.username)
        } label: {
            Image("ZoneListAddFloating")
                .resizable().scaledToFit().frame(width: 25, height: 25)
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

private extension View {
    func boardListRow(bottom: CGFloat) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: bottom, trailing: 24))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
