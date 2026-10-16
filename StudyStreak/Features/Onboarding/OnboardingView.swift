import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage: OnboardingPage

    init(initialPage: OnboardingPage = .study, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button("Skip", action: onComplete)
                    .font(AppTypography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.primary)
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityHint("Finish the introduction")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $selectedPage) {
                ForEach(OnboardingPage.allCases) { page in
                    OnboardingPageView(page: page, onContinue: advance)
                        .accessibilityHidden(page != selectedPage)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 26) {
                pageIndicator

                PrimaryButton(title: selectedPage.buttonTitle, action: advance)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .frame(maxWidth: 478)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
    }

    private var pageIndicator: some View {
        Button {
            select(selectedPage.next ?? .study)
        } label: {
            HStack(spacing: 8) {
                ForEach(OnboardingPage.allCases) { page in
                    Capsule()
                        .fill(page == selectedPage ? AppColors.primary : AppColors.border)
                        .frame(width: page == selectedPage ? 24 : 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Introduction pages")
        .accessibilityValue("Page \(selectedPage.rawValue + 1) of \(OnboardingPage.allCases.count)")
        .accessibilityHint("Double tap to view the next page")
        .accessibilityAction(named: "Previous page") {
            if let previous = OnboardingPage(rawValue: selectedPage.rawValue - 1) {
                select(previous)
            }
        }
    }

    private func advance() {
        if let next = selectedPage.next {
            select(next)
        } else {
            onComplete()
        }
    }

    private func select(_ page: OnboardingPage) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            selectedPage = page
        }
    }
}

#Preview("01 · Study without thinking") {
    OnboardingView(onComplete: {})
}

#Preview("02 · Your study zones") {
    OnboardingView(initialPage: .zones, onComplete: {})
}

#Preview("03 · Build a streak") {
    OnboardingView(initialPage: .streak, onComplete: {})
}

#Preview("Onboarding · Dark") {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
