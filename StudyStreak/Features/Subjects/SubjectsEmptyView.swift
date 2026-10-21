import SwiftUI

struct SubjectsEmptyView: View {
    let canAddSubject: Bool
    let onAddSubject: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Text("A place for every kind of curiosity.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Image("SubjectsEmptyBooks")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 281)
                        .frame(height: 232)
                        .padding(.top, 72)
                        .accessibilityHidden(true)

                    Text("Every subject has a place.")
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 40)
                        .accessibilityAddTraits(.isHeader)

                    Text("Add your first subject to organize your sessions, one color at a time.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    PrimaryButton(title: "Add your first subject", action: onAddSubject)
                        .disabled(!canAddSubject)
                        .padding(.top, 40)

                    Text("Your subjects will appear in study zones.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 430, minHeight: geometry.size.height, alignment: .top)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
