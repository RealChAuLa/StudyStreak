import SwiftUI

struct AppLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAppeared = false

    private var animates: Bool { !reduceMotion && scenePhase == .active }
    private var entrance: Animation {
        .timingCurve(0, 0, 0.58, 1, duration: LoadingMotion.entranceDuration)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    mark
                    branding
                    loadingDots
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("Getting things ready…")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("StudyStreak. Getting things ready.")
        .onAppear { hasAppeared = true }
    }

    private var mark: some View {
        ZStack {
            Image("LoadingMark")
                .resizable().scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .scaleEffect(animates && !hasAppeared ? 0.92 : 1)
                .offset(y: animates && !hasAppeared ? 8 : 0)
                .opacity(animates && !hasAppeared ? 0 : 1)
                .animation(animates ? entrance : nil, value: hasAppeared)
        }
        .frame(width: 176, height: 176)
        .accessibilityHidden(true)
    }

    private var branding: some View {
        VStack(spacing: 8) {
            Text("StudyStreak")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.text)
            Text("A little focus, every day.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
        .opacity(animates && !hasAppeared ? 0 : 1)
        .animation(animates ? entrance.delay(LoadingMotion.brandDelay) : nil, value: hasAppeared)
    }

    private var loadingDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                if animates {
                    LoadingDot(delay: Double(index) * LoadingMotion.dotStagger)
                } else {
                    Image("LoadingDot").resizable().scaledToFit()
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .opacity(index == 0 ? 1 : 0.25)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LoadingDot: View {
    let delay: Double

    var body: some View {
        Image("LoadingDot").resizable().scaledToFit()
            .foregroundStyle(AppColors.primary)
            .frame(width: 8, height: 8)
            .keyframeAnimator(initialValue: 0.25) { dot, opacity in
                dot.opacity(opacity)
            } keyframes: { _ in
                LinearKeyframe(0.25, duration: delay)
                LinearKeyframe(1, duration: LoadingMotion.dotFade)
                LinearKeyframe(0.25, duration: LoadingMotion.dotFade)
                LinearKeyframe(0.25, duration: LoadingMotion.dotRest - delay)
            }
    }
}

// loading screen animations
nonisolated private enum LoadingMotion {
    static let entranceDuration = 0.6
    static let brandDelay = 0.18
    static let haloHalfCycle = 1.8
    static let dotStagger = 0.15
    static let dotFade = 0.3
    static let dotRest = 0.6
}

#Preview("App loading · Light") {
    AppLoadingView().preferredColorScheme(.light)
}

#Preview("App loading · Dark") {
    AppLoadingView().preferredColorScheme(.dark)
}

#Preview("App loading · SE", traits: .fixedLayout(width: 375, height: 667)) {
    AppLoadingView()
}
