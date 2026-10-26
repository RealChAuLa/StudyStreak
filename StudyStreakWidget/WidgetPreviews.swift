import Foundation
import SwiftUI
import WidgetKit

struct StudyStreakWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            StudyProgressWidgetView(entry: .preview())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small · Streak and today")
            StudyProgressWidgetView(entry: .preview())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium · Seven-day rhythm")
            StudyProgressWidgetView(entry: .preview())
                .environment(\.colorScheme, .dark)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium · Dark")
            StudyProgressWidgetView(entry: StudyProgressEntry(date: .now, state: .signedOut, metrics: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small · Signed out")
        }
    }
}
