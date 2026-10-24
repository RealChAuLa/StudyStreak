import SwiftUI

struct AutomaticSessionConfirmationView: View {
    let session: SessionRecord
    let onConfirm: () -> Void
    let onChangeSubject: () -> Void
    @State private var hasInteracted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("AutomaticSessionLocation").resizable().scaledToFit().frame(width: 28, height: 28)
                    .foregroundStyle(AppColors.success).accessibilityHidden(true)
                Text("Your session has started")
                    .font(AppTypography.title2).foregroundStyle(AppColors.text)
                    .accessibilityAddTraits(.isHeader)
                Text("Studying \(session.subject.name) at \(session.zoneName ?? "your study zone")")
                    .font(AppTypography.body).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    PrimaryButton(title: "That’s right", action: onConfirm)
                    Button("Change subject", action: onChangeSubject)
                        .font(AppTypography.headline).foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .background(AppColors.surface.ignoresSafeArea())
        .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in hasInteracted = true })
        .task(id: session.id) {
            let delay = min(10, max(0, session.confirmationExpiresAt?.timeIntervalSinceNow ?? 0))
            do {
                try await Task.sleep(for: .seconds(delay))
                try Task.checkCancellation()
                if !hasInteracted { onConfirm() }
            } catch { }
        }
    }
}
