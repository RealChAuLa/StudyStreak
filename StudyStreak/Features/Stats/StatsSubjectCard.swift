import Charts
import SwiftUI

struct StatsSubjectCard: View {
    let totals: [StatsSubjectTotal]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By subject").font(AppTypography.title2).foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            if totals.isEmpty {
                Text("Your subject breakdown will appear after you spend some time studying.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) { donut; legend }
            } else {
                HStack(spacing: 16) { donut; legend }
            }
        }
        .studySessionCard()
    }

    private var donut: some View {
        Chart(totals) { total in
            SectorMark(angle: .value("Study time", total.seconds),
                       innerRadius: .ratio(0.76), angularInset: 1)
                .foregroundStyle(total.subject.color)
                .accessibilityLabel(total.subject.name)
                .accessibilityValue(StudyTime.duration(total.seconds))
        }
        .chartLegend(.hidden)
        .frame(width: 126, height: 126)
        .overlay {
            VStack(spacing: 0) {
                Text("\(totals.count)")
                    .font(.custom("GoogleSans-Bold", size: 28, relativeTo: .title))
                    .foregroundStyle(AppColors.text)
                Text(totals.count == 1 ? "subject" : "subjects")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
            }
            .accessibilityHidden(true)
        }
        .accessibilityLabel("Study time by subject")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(totals) { total in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(total.subject.color).frame(width: 8, height: 8)
                        .padding(.top, 4).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(total.subject.name).font(AppTypography.caption.weight(.medium))
                            .foregroundStyle(AppColors.text)
                        Text(StudyTime.duration(total.seconds)).font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
