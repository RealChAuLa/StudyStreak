import SwiftUI
import WidgetKit

@main
struct StudyStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StudyWidgetConfiguration.kind, provider: StudyProgressProvider()) { entry in
            StudyProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("StudyStreak")
        .description("Your streak, today's study time, and a little encouragement.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
