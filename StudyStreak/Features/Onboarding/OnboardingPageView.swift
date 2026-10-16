import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var titleHeight: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var messageHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var messageLineSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(1, min(geometry.size.width - 48, 430))
            let illustrationHeight = contentWidth * 280 / 345
            let spareHeight = geometry.size.height - illustrationHeight - titleHeight - messageHeight - 62
            let topPadding = min(49, max(0, spareHeight * 0.65))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onContinue) {
                        Image(page.imageName)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(width: contentWidth, height: illustrationHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 22) {
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
                    .padding(.top, 40)
                }
                .frame(width: contentWidth)
                .padding(.top, topPadding)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
