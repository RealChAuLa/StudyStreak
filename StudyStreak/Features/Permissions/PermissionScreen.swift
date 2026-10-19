import SwiftUI

struct PermissionScreen: View {
    let page: PermissionPage
    var primaryTitle: String? = nil
    var contextMessage: String? = nil
    var isPrimaryDisabled = false
    let onPrimary: () -> Void
    let onSkip: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleHeight: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var messageHeight: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var messageLineSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image(page.imageName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 169, height: 169)
                        .background(AppColors.tint, in: RoundedRectangle(cornerRadius: 48))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 47)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 24) {
                        Text(page.title)
                            .font(AppTypography.largeTitle)
                            .foregroundStyle(AppColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .topLeading)
                            .accessibilityAddTraits(.isHeader)

                        Text(page.message)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondary)
                            .lineSpacing(messageLineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: messageHeight, alignment: .topLeading)
                    }

                    contextCard
                        .padding(.top, 31)
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 24)
                .padding(.top, min(113, max(24, geometry.size.height - 524)))
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                PrimaryButton(title: primaryTitle ?? page.buttonTitle, action: onPrimary)
                    .disabled(isPrimaryDisabled)

                Button("Maybe Later", action: onSkip)
                    .font(AppTypography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityHint("Continue without changing this permission")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(maxWidth: 478)
            .frame(maxWidth: .infinity)
            .background(AppColors.background)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var contextCard: some View {
        HStack(spacing: 12) {
            Image(page.contextImageName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(AppColors.primary)
                .accessibilityHidden(true)

            Text(contextMessage ?? page.contextMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.text.opacity(0.05), radius: 16, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("04 · Location permission") {
    PermissionScreen(page: .location, onPrimary: {}, onSkip: {})
}

#Preview("05 · Notification permission") {
    PermissionScreen(page: .notifications, onPrimary: {}, onSkip: {})
}

#Preview("Permissions · Dark") {
    PermissionScreen(page: .location, onPrimary: {}, onSkip: {})
        .preferredColorScheme(.dark)
}

#Preview("Permissions · Large text") {
    PermissionScreen(page: .notifications, onPrimary: {}, onSkip: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
