import SwiftUI

struct ProfileRoutineSection: View {
    @State private var preferences: RoutinePreferences

    init(ownerID: String) {
        _preferences = State(initialValue: RoutinePreferences(ownerID: ownerID))
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                DailyGoalView(preferences: preferences)
            } label: {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    row("Daily Goal", icon: "ProfileClock", value: goalLabel(at: context.date))
                }
            }.buttonStyle(.plain)
            Divider().overlay(AppColors.border)
            NavigationLink {
                NotificationPreferencesView(preferences: preferences)
            } label: {
                row("Notifications", icon: "ProfileBell", value: nil)
            }.buttonStyle(.plain)
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func goalLabel(at date: Date) -> String {
        if let pending = preferences.settings.goals.last, pending.effectiveFrom > date {
            return "\(RoutineSettings.duration(pending.minutes)) tomorrow"
        }
        return RoutineSettings.duration(preferences.settings.goal(on: date))
    }

    private func row(_ title: String, icon: String, value: String?) -> some View {
        HStack(spacing: 12) {
            Image(icon).resizable().scaledToFit().frame(width: 22, height: 22)
                .foregroundStyle(AppColors.primary).accessibilityHidden(true)
            Text(title).font(AppTypography.body).foregroundStyle(AppColors.text)
            Spacer(minLength: 0)
            if let value {
                Text(value).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .multilineTextAlignment(.trailing)
            }
            Image("ProfileChevron").resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
        }
        .frame(minHeight: 48).padding(.vertical, 4).contentShape(Rectangle())
    }
}
