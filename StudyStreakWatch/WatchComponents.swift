import SwiftUI

struct WatchActionButton: View {
    enum Style { case primary, secondary, destructive }

    let title: String
    var style: Style = .primary
    var isBusy = false
    let action: () -> Void

    private var foreground: Color {
        switch style {
        case .primary: AppColors.onPrimary
        case .secondary: AppColors.text
        case .destructive: AppColors.danger
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WatchTypography.button)
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(style == .primary ? AppColors.primary : AppColors.surface, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.7 : 1)
        .accessibilityValue(isBusy ? "Waiting for iPhone" : "")
    }
}

struct WatchSubjectButton: View {
    let subject: WatchSubject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("WatchSubject")
                    .resizable().scaledToFit()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                Text(subject.name)
                    .font(WatchTypography.subject)
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image("WatchChevron")
                    .resizable().scaledToFit()
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subject.name)
    }
}

struct WatchConnectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image("WatchStatusDot")
                .resizable().frame(width: 5, height: 5)
                .accessibilityHidden(true)
            Text(title)
                .font(WatchTypography.small)
                .foregroundStyle(AppColors.secondary)
        }
    }
}

