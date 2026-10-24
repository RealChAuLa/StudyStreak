import SwiftUI

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.rank.map { String($0) } ?? "—")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.secondary)
                .frame(minWidth: 18)
                .accessibilityHidden(true)
            ProfileAvatar(initial: entry.profile.initial, photoData: entry.profile.photoData, size: 40)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    identity
                    duration
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                identity.frame(maxWidth: .infinity, alignment: .leading)
                duration
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(entry.isCurrentUser ? AppColors.tint : AppColors.surface,
                    in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("@\(entry.profile.username)")
                .font(AppTypography.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image("FriendFlame")
                    .resizable().scaledToFit().frame(width: 12, height: 12)
                    .foregroundStyle(AppColors.accent)
                    .accessibilityHidden(true)
                Text(entry.streakDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var duration: some View {
        Text(entry.duration)
            .font(AppTypography.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.text)
            .monospacedDigit()
            .fixedSize()
    }

    private var accessibilityDescription: String {
        let rank = entry.rank.map { "Rank \($0). " } ?? "Unranked. "
        let time = entry.seconds == nil ? "Study time not available yet" : "\(entry.duration) studied"
        return "\(rank)\(entry.profile.username). \(entry.streakDescription). \(time)."
    }
}

#Preview("Friends · ranked rows") {
    VStack(spacing: 8) {
        LeaderboardRow(entry: LeaderboardEntry(
            profile: FriendProfile(id: "friend", username: "anuki", displayName: "Anuki", photoBase64: nil),
            seconds: 65_400, streak: 18, isCurrentUser: false, isPrivate: false, rank: 1))
        LeaderboardRow(entry: LeaderboardEntry(
            profile: FriendProfile(id: "me", username: "devinda", displayName: "Devinda", photoBase64: nil),
            seconds: 51_900, streak: 12, isCurrentUser: true, isPrivate: false, rank: 3))
    }
    .padding(24)
    .background(AppColors.background)
}
