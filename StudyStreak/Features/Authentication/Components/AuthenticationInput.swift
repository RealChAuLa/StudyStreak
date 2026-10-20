import SwiftUI

struct AuthenticationInput<Content: View>: View {
    let isFocused: Bool
    let hasError: Bool
    private let content: Content

    init(isFocused: Bool, hasError: Bool, @ViewBuilder content: () -> Content) {
        self.isFocused = isFocused
        self.hasError = hasError
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.text)
        .tint(AppColors.primary)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
        }
    }

    private var borderColor: Color {
        if hasError { return AppColors.danger }
        return isFocused ? AppColors.primary : AppColors.border
    }
}
