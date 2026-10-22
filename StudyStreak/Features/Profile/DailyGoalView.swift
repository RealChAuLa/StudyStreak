import SwiftUI

struct DailyGoalView: View {
    let preferences: RoutinePreferences
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Double

    init(preferences: RoutinePreferences) {
        self.preferences = preferences
        _minutes = State(initialValue: Double(preferences.settings.selectedGoal))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("A rhythm that fits your life.")
                    .font(AppTypography.title2).foregroundStyle(AppColors.text)
                Text("Pick a daily study goal that feels achievable. Consistency starts small.")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondary)
                goalCard
                Text("Reach your goal to keep your streak.\nChanges apply from tomorrow.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            }
            .padding(.horizontal, 24).padding(.top, 40).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Daily goal").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Save Goal") {
                preferences.settings.setGoal(Int(minutes))
                dismiss()
            }
            .padding(24).background(AppColors.background)
        }
    }

    private var goalCard: some View {
        VStack(spacing: 24) {
            Text(RoutineSettings.duration(Int(minutes)))
                .font(.custom("GoogleSans-Bold", size: 48, relativeTo: .largeTitle))
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            HStack(spacing: 16) {
                adjustment("−", label: "Decrease goal by 15 minutes", disabled: minutes <= 15) { minutes -= 15 }
                Text("\(Int(minutes)) min").font(AppTypography.title2)
                    .foregroundStyle(AppColors.text).frame(maxWidth: .infinity)
                adjustment("+", label: "Increase goal by 15 minutes", disabled: minutes >= 240) { minutes += 15 }
            }
            Slider(value: $minutes, in: 15...240, step: 15)
                .tint(AppColors.primary).frame(minHeight: 44)
                .accessibilityLabel("Daily study goal")
                .accessibilityValue("\(Int(minutes)) minutes")
            HStack {
                Text("15 min")
                Spacer()
                Text("4 hours")
            }
            .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    private func adjustment(_ title: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(AppTypography.headline).foregroundStyle(AppColors.primary)
            .frame(width: 72, height: 56)
            .background(AppColors.tint, in: RoundedRectangle(cornerRadius: 16))
            .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.4 : 1)
            .accessibilityLabel(label)
    }
}
