import SwiftUI

struct GoogleAuthenticationButton: View {
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("GoogleG")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                Text("Continue with Google")
                    .font(AppTypography.googleButton)
                    .foregroundStyle(AppColors.tagText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            // Google's light button keeps a white surface in either app appearance.
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppColors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .opacity(isEnabled ? 1 : 0.5)
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
    }
}
