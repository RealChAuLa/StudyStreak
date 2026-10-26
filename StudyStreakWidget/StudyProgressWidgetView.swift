import Foundation
import Charts
import SwiftUI
import WidgetKit

struct StudyProgressWidgetView: View {
    let entry: StudyProgressEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var isSmall: Bool { family == .systemSmall }
    private var primaryInk: Color {
        renderingMode == .fullColor ? (isSmall ? AppColors.tagText : AppColors.text) : .primary
    }
    private var secondaryInk: Color {
        renderingMode == .fullColor ? (isSmall ? AppColors.tagText : AppColors.secondary) : .secondary
    }
    private var flameInk: Color {
        renderingMode == .fullColor ? (isSmall ? AppColors.tagText : AppColors.accent) : .primary
    }

    var body: some View {
        Group {
            if let metrics = entry.metrics {
                if isSmall { small(metrics) } else { medium(metrics) }
            } else {
                invitation
            }
        }
        .containerBackground(for: .widget) { isSmall ? AppColors.accent : AppColors.warm }
        .widgetURL(StudyWidgetConfiguration.homeURL)
        .privacySensitive()
    }

    private func small(_ metrics: HomeStudyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            streak(metrics.streak, size: 46, small: true)
            Text("day streak").font(AppTypography.subheadline.weight(.medium))
                .foregroundStyle(primaryInk).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Rectangle().fill(primaryInk).frame(height: 1).accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(minutes(metrics))")
                    .font(.custom("GoogleSans-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(primaryInk).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    .layoutPriority(1)
                Text("min today").font(AppTypography.caption).foregroundStyle(secondaryInk)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if metrics.progress >= 1 { goalCheck }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(minutes(metrics)) minutes studied today\(metrics.progress >= 1 ? ", daily goal reached" : "")")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ metrics: HomeStudyMetrics) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    streak(metrics.streak, size: 40, small: false)
                    Text("day streak").font(AppTypography.caption.weight(.medium))
                        .foregroundStyle(secondaryInk).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        Text("\(minutes(metrics)) min").font(AppTypography.title2)
                            .foregroundStyle(primaryInk).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.65)
                        if metrics.progress >= 1 { goalCheck }
                    }
                    Text("studied today").font(AppTypography.caption).foregroundStyle(secondaryInk)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: geometry.size.width * 0.35, alignment: .leading)
                chart(metrics).frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func streak(_ count: Int, size: CGFloat, small: Bool) -> some View {
        HStack(spacing: 8) {
            Image(small ? "WidgetFlameSmall" : "WidgetFlameMedium")
                .resizable().widgetAccentedRenderingMode(.accented).scaledToFit()
                .frame(width: small ? 28 : 27, height: small ? 28 : 27)
                .foregroundStyle(flameInk).accessibilityHidden(true)
            Text("\(count)").font(.custom("GoogleSans-Bold", size: size, relativeTo: .largeTitle))
                .foregroundStyle(primaryInk).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) day study streak")
    }

    private var goalCheck: some View {
        Image(systemName: "checkmark.circle.fill").font(.caption)
            .foregroundStyle(primaryInk).accessibilityHidden(true)
    }

    private func chart(_ metrics: HomeStudyMetrics) -> some View {
        Chart(metrics.days) { day in
            BarMark(x: .value("Day", day.date, unit: .day),
                    y: .value("Study minutes", day.seconds / 60), width: .ratio(0.56))
                .cornerRadius(4)
                .foregroundStyle(Calendar.current.isDate(day.date, inSameDayAs: entry.date)
                                 ? AppColors.primary : AppColors.Subject.blue.opacity(0.55))
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                .accessibilityValue("\(max(0, Int(day.seconds / 60))) minutes")
        }
        .chartYScale(domain: 0...max(30, (metrics.days.map { $0.seconds / 60 }.max() ?? 0) * 1.1))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: metrics.days.map(\.date)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(AppTypography.caption).foregroundStyle(secondaryInk)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 103)
        .widgetAccentable()
        .accessibilityLabel("Study time over the last seven days")
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(isSmall ? "WidgetFlameSmall" : "WidgetFlameMedium")
                .resizable().widgetAccentedRenderingMode(.accented).scaledToFit()
                .frame(width: isSmall ? 28 : 27, height: isSmall ? 28 : 27).foregroundStyle(flameInk).accessibilityHidden(true)
            Text("A little focus,\nevery day.").font(AppTypography.headline).foregroundStyle(primaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(entry.state == .signedOut ? "Sign in to see your progress." : "Open StudyStreak to see your progress.")
                .font(AppTypography.caption).foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func minutes(_ metrics: HomeStudyMetrics) -> Int {
        max(0, Int(metrics.todaySeconds / 60))
    }
}
