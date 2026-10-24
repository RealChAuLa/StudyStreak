import SwiftUI

@MainActor
extension SessionSubject {
    var color: Color { (SubjectColor(rawValue: colorID) ?? .blue).color }
    var icon: SubjectIcon { SubjectIcon(rawValue: iconID) ?? .book }
}

struct SessionSubjectPill: View {
    let subject: SessionSubject
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            SubjectIconImage(icon: subject.icon, size: 16)
            Text(subject.name)
                .font(AppTypography.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppColors.tagText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: height)
        .background(subject.color, in: Capsule())
    }
}

struct SessionCloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image("SessionClose").resizable().scaledToFit().frame(width: 18, height: 18)
                .foregroundStyle(AppColors.secondary)
                .frame(width: 44, height: 44)
                .background(AppColors.border, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

struct SessionActivityDot: View {
    let isRunning: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Circle().fill(isRunning ? AppColors.success : AppColors.secondary)
            .frame(width: 8, height: 8)
            .opacity(isPulsing ? 0.45 : 1)
            .animation(isRunning && !reduceMotion
                       ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : nil,
                       value: isPulsing)
            .onAppear { isPulsing = isRunning && !reduceMotion }
            .onChange(of: isRunning) { _, value in isPulsing = value && !reduceMotion }
            .onChange(of: reduceMotion) { _, value in isPulsing = isRunning && !value }
            .accessibilityHidden(true)
    }
}

extension View {
    func studySessionCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: AppColors.text.opacity(0.04), radius: 8, y: 4)
    }
}
