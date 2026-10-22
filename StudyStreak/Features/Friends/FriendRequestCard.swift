import SwiftUI

struct FriendRequestCard: View {
    let profile: FriendProfile?
    let incoming: Bool
    let profileUnavailable: Bool
    let busy: Bool
    let enabled: Bool
    let onAction: (FriendAction) -> Void

    private var username: String {
        profile?.username ?? (profileUnavailable ? "Profile unavailable" : "Loading profile…")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(incoming ? "INCOMING" : "OUTGOING")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondary)
            if incoming {
                incomingContent
            } else {
                HStack(spacing: 12) {
                    Text(username)
                        .font(AppTypography.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(busy ? "Cancelling…" : "Cancel") { onAction(.cancel) }
                        .font(AppTypography.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.primary)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                        .disabled(!enabled || busy)
                        .accessibilityLabel("Cancel request to \(username)")
                }
            }
        }
    }

    private var incomingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProfileAvatar(initial: profile?.initial ?? "?", photoData: profile?.photoData, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(username).font(AppTypography.body.weight(.medium)).foregroundStyle(AppColors.text)
                    Text("Wants to study alongside you")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if busy {
                ProgressView("Updating request…")
                    .font(AppTypography.caption).tint(AppColors.primary)
                    .frame(maxWidth: .infinity, minHeight: 56)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { acceptButton; declineButton }
                    VStack(spacing: 12) { acceptButton; declineButton }
                }
            }
        }
    }

    private var acceptButton: some View {
        PrimaryButton(title: "Accept") { onAction(.accept) }
            .disabled(!enabled || profile == nil)
            .accessibilityLabel("Accept request from \(username)")
    }

    private var declineButton: some View {
        Button { onAction(.decline) } label: {
            Text("Decline").font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .padding(.horizontal, 16).padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AppColors.tint, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("Decline request from \(username)")
    }
}

#Preview("Incoming request") {
    FriendRequestCard(profile: FriendProfile(id: "preview", username: "ravindu.tech", displayName: "Ravindu", photoBase64: nil),
                      incoming: true, profileUnavailable: false, busy: false, enabled: true, onAction: { _ in })
        .padding(16).background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(24).background(AppColors.background)
}
