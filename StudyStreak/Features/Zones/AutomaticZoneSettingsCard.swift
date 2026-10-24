import SwiftUI

struct AutomaticZoneSettingsCard: View {
    let runtime: StudyRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Let your routine do the remembering.")
                .font(AppTypography.headline).foregroundStyle(AppColors.text)
            Toggle("Automatic tracking", isOn: Binding(
                get: { runtime.zones.isEnabled },
                set: { runtime.zones.setEnabled($0) }
            ))
            .font(AppTypography.body).foregroundStyle(AppColors.text).tint(AppColors.success)
            Text(runtime.zones.statusMessage)
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if runtime.zones.isEnabled, let title = runtime.zones.permissionButtonTitle {
                Button(title) { runtime.zones.requestPermission() }
                    .font(AppTypography.headline).foregroundStyle(AppColors.primary)
                    .frame(minHeight: 44).buttonStyle(.plain)
            }
            if !runtime.zones.monitoringErrors.isEmpty || runtime.automationError != nil {
                if let error = runtime.automationError {
                    Text(error).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                }
                Button("Refresh zones") { runtime.refresh() }
                    .font(AppTypography.headline).foregroundStyle(AppColors.primary)
                    .frame(minHeight: 44).buttonStyle(.plain)
            }
        }
        .studySessionCard()
    }
}
