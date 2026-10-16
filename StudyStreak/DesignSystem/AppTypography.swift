import SwiftUI

enum AppTypography {
    static let largeTitle = Font.custom("GoogleSans-Bold", size: 34, relativeTo: .largeTitle)
    static let title2 = Font.custom("GoogleSans-SemiBold", size: 22, relativeTo: .title2)
    static let headline = Font.custom("GoogleSans-SemiBold", size: 17, relativeTo: .headline)
    static let body = Font.custom("GoogleSans-Regular", size: 17, relativeTo: .body)
    static let subheadline = Font.custom("GoogleSans-Regular", size: 15, relativeTo: .subheadline)
    static let caption = Font.custom("GoogleSans-Regular", size: 12, relativeTo: .caption)
}
