import SwiftData
import SwiftUI

struct ZonesEmptyView: View {
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 64)

                    Image("ZonesEmptyMap")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 281)
                        .frame(height: 232)
                        .accessibilityHidden(true)

                    VStack(spacing: 16) {
                        Text("Your focus has a place.")
                            .font(AppTypography.title2)
                            .foregroundStyle(AppColors.text)
                            .accessibilityAddTraits(.isHeader)
                        Text("Add your first study zone and let your routine take care of the timer.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondary)
                            .lineSpacing(3)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 40)

                    PrimaryButton(title: "Add your first study zone", action: onAdd)
                    .disabled(!canAdd)
                    .padding(.top, 48)

                    Text("Library, home desk, or your favorite café.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: 430, minHeight: geometry.size.height)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColors.background.ignoresSafeArea())
    }
}

#Preview("18 · Zones / empty") {
    NavigationStack { ZonesView() }
        .tint(AppColors.primary)
        .environment(\.studyUserID, "preview")
        .modelContainer(for: StudySubject.self, inMemory: true)
}

#Preview("Zones / empty · Dark") {
    NavigationStack { ZonesView() }
        .tint(AppColors.primary)
        .environment(\.studyUserID, "preview")
        .modelContainer(for: StudySubject.self, inMemory: true)
        .preferredColorScheme(.dark)
}
