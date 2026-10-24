import SwiftUI

struct LeaderboardVisibilityRow: View {
    @State private var model: LeaderboardVisibilityModel

    init(ownerID: String) {
        _model = State(initialValue: LeaderboardVisibilityModel(userID: ownerID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Leaderboard visibility", isOn: Binding(
                get: { model.isVisible },
                set: { value in Task { await model.setVisible(value) } }
            ))
            .font(AppTypography.body)
            .foregroundStyle(AppColors.text)
            .tint(AppColors.success)
            .disabled(!model.isLoaded || model.isSaving)
            .padding(.top, 12)
            .frame(minHeight: 44)

            Text("Choose whether friends can see your study totals and streak.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.isSaving {
                ProgressView("Saving…").font(AppTypography.caption)
            }
            if let error = model.errorMessage {
                Text(error).font(AppTypography.caption).foregroundStyle(AppColors.danger)
                Button("Try again") { model.start() }
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.primary)
                    .frame(minHeight: 44)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
