import SwiftUI
import UIKit

struct UsernameShareCard: View {
    let username: String
    @State private var copyCount = 0
    @State private var isCopied = false

    private var invitation: String {
        "Join my study circle on StudyStreak! Search for @\(username) in Add Friends. A little focus, together."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR USERNAME")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondary)
            HStack(spacing: 4) {
                Text("@\(username)")
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    UIPasteboard.general.string = username
                    isCopied = true
                    copyCount += 1
                    UIAccessibility.post(notification: .announcement, argument: "Username copied")
                } label: { icon("FriendCopy") }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy username")
                ShareLink(item: invitation) { icon("FriendShare") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share username")
            }
            Text(isCopied ? "Username copied." : "Share this with your study circle.")
                .font(AppTypography.caption)
                .foregroundStyle(isCopied ? AppColors.successText : AppColors.secondary)
        }
        .task(id: copyCount) {
            guard copyCount > 0 else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                isCopied = false
            } catch { }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(name).resizable().scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundStyle(AppColors.primary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

#Preview("Share username") {
    UsernameShareCard(username: "devinda.studies").padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .padding(24).background(AppColors.background)
}
