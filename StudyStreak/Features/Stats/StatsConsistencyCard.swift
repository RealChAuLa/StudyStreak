import SwiftUI

struct StatsConsistencyCard: View {
    let weeks: [StatsHeatmapWeek]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A little, often.").font(AppTypography.title2).foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            Text("Your last 12 weeks of showing up")
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            grid
            key
            Text("Each column is a week, Monday to Sunday. Full color means your daily goal was reached.")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .studySessionCard()
    }

    private var grid: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(weeks) { week in
                VStack(spacing: 3) {
                    Text(week.monthLabel).font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize()
                        .frame(width: 12, height: 20, alignment: .leading)
                        .accessibilityHidden(true)
                    ForEach(week.days) { day in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: day))
                            .frame(width: 12, height: 12)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                            .accessibilityValue(description(for: day))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.trailing, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("12-week study consistency")
    }

    private var key: some View {
        HStack(spacing: 8) {
            Text("Less")
            ForEach(1...4, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(AppColors.primary.opacity(Double(level) / 4))
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
            }
            Text("More")
        }
        .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
        .accessibilityHidden(true)
    }

    private func color(for day: StatsHeatmapDay) -> Color {
        if day.isFuture { return AppColors.border.opacity(0.35) }
        if day.seconds == 0 { return AppColors.border }
        return AppColors.primary.opacity(0.2 + 0.8 * day.intensity)
    }

    private func description(for day: StatsHeatmapDay) -> String {
        if day.isFuture { return "Upcoming day" }
        if day.seconds == 0 { return "No study time" }
        return "\(StudyTime.duration(day.seconds)), \(day.reachedGoal ? "daily goal reached" : "daily goal not reached")"
    }
}
