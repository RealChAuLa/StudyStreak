import Foundation
import SwiftUI

enum WatchTypography {
    static let title = Font.custom("GoogleSans-SemiBold", size: 20, relativeTo: .title3)
    static let button = Font.custom("GoogleSans-SemiBold", size: 15, relativeTo: .headline)
    static let body = Font.custom("GoogleSans-Regular", size: 14, relativeTo: .body)
    static let subject = Font.custom("GoogleSans-Regular", size: 13, relativeTo: .body)
    static let caption = Font.custom("GoogleSans-Regular", size: 12, relativeTo: .caption)
    static let small = Font.custom("GoogleSans-Regular", size: 11, relativeTo: .caption2).weight(.medium)

    static func timer(compact: Bool) -> Font {
        .custom("GoogleSans-Regular", size: compact ? 34 : 38, relativeTo: .largeTitle).weight(.medium)
    }
}

enum WatchTime {
    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds)) / 60
        if seconds > 0 && seconds < 60 { return "<1 min" }
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }
}

