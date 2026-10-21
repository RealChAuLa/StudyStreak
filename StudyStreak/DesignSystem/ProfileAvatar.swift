import SwiftUI
import UIKit

struct ProfileAvatar: View {
    let initial: String
    let photoData: Data?
    var size: CGFloat = 144

    var body: some View {
        ZStack {
            Circle().fill(AppColors.tint)
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(initial)
                    .font(.custom("GoogleSans-SemiBold", size: size * 52 / 144, relativeTo: .largeTitle))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
