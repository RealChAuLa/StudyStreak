import Charts
import SwiftUI

struct StatsStudyTimeCard: View {
    let snapshot: StatsSnapshot
    @State private var selectedBarID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.title).font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            summary
            Text(encouragement).font(AppTypography.subheadline)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            chart.padding(.top, 8)
            if let selectedBar {
                Text("\(selectedBar.detail) · \(StudyTime.duration(selectedBar.seconds))")
                    .font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(footer).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if snapshot.period != .day, snapshot.previousSeconds >= 1 {
                Text(snapshot.period == .week
                     ? "Compared with the same point last week."
                     : "Compared with the same point last month.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .studySessionCard()
        .onChange(of: snapshot.period) { _, _ in selectedBarID = nil }
        .onChange(of: snapshot.title) { _, _ in selectedBarID = nil }
    }

    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                total
                Spacer(minLength: 0)
                comparison
            }
            VStack(alignment: .leading, spacing: 4) { total; comparison }
        }
    }

    private var total: some View {
        Text(StudyTime.duration(snapshot.totalSeconds)).font(AppTypography.largeTitle)
            .foregroundStyle(AppColors.text).monospacedDigit().fixedSize()
            .accessibilityLabel("Total study time: \(StudyTime.duration(snapshot.totalSeconds))")
    }

    @ViewBuilder private var comparison: some View {
        if snapshot.period == .day {
            let percent = Int((snapshot.totalSeconds / Double(snapshot.goalMinutes * 60) * 100).rounded(.down))
            Text("\(percent)% of goal")
                .font(AppTypography.caption.weight(.medium)).foregroundStyle(AppColors.successText)
        } else if let percent = snapshot.comparisonPercent {
            Text("\(percent > 0 ? "+" : "")\(percent)% vs last")
                .font(AppTypography.caption.weight(.medium))
                .foregroundStyle(percent > 0 ? AppColors.successText : AppColors.secondary)
        }
    }

    private var chart: some View {
        Chart(snapshot.bars) { bar in
            BarMark(x: .value("Period", String(bar.id)),
                    y: .value("Study minutes", bar.seconds / 60), width: .ratio(0.56))
                .cornerRadius(4)
                .foregroundStyle(bar.isCurrent ? AppColors.primary : AppColors.Subject.blue.opacity(0.55))
                .opacity(selectedBarID == nil || selectedBarID == String(bar.id) ? 1 : 0.45)
                .accessibilityLabel(bar.detail)
                .accessibilityValue(StudyTime.duration(bar.seconds))
        }
        .chartYScale(domain: 0...axisMaximum)
        .chartYAxis {
            AxisMarks(position: .leading, values: axisValues) { value in
                AxisGridLine().foregroundStyle(AppColors.border)
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(axisLabel(minutes)).font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: axisLabels) { value in
                AxisValueLabel {
                    if let id = value.as(String.self),
                       let bar = snapshot.bars.first(where: { String($0.id) == id }) {
                        Text(bar.label).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartXSelection(value: $selectedBarID)
        .frame(height: 150)
        .overlay {
            if snapshot.totalSeconds == 0 {
                Text("No study time yet")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .padding(8).background(AppColors.surface, in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("\(snapshot.period.rawValue) study time")
        .accessibilityHint("Touch and hold a bar to inspect its study time.")
    }

    private var selectedBar: StatsBar? {
        snapshot.bars.first { String($0.id) == selectedBarID }
    }

    private var axisMaximum: Double {
        let largest = (snapshot.bars.map(\.seconds).max() ?? 0) / 60
        guard largest > 0 else {
            return snapshot.period == .day ? 60 : snapshot.period == .week ? 180 : 1200
        }
        let steps: [Double] = [1, 2, 5, 10, 20, 30, 60, 120, 240, 480, 960, 1440, 2880, 5760]
        let step = steps.first { $0 >= largest / 3 } ?? ceil(largest / 3)
        return step * 3
    }

    private var axisValues: [Double] {
        [axisMaximum / 3, axisMaximum * 2 / 3, axisMaximum]
    }

    private var axisLabels: [String] {
        let bars = snapshot.bars
        guard bars.count > 7 else { return bars.map { String($0.id) } }
        let stride = max(1, Int(ceil(Double(bars.count) / 4)))
        return bars.enumerated().filter { $0.offset.isMultiple(of: stride) || $0.offset == bars.count - 1 }
            .map { String($0.element.id) }
    }

    private func axisLabel(_ minutes: Double) -> String {
        if minutes < 60 { return "\(Int(minutes.rounded()))m" }
        let hours = minutes / 60
        return hours.rounded() == hours ? "\(Int(hours))h" : "\(hours.formatted(.number.precision(.fractionLength(1))))h"
    }

    private var encouragement: String {
        if snapshot.totalSeconds == 0 { return "Your next little session starts here." }
        return snapshot.period == .day ? "A little focus is adding up." : "More time for what matters."
    }

    private var footer: String {
        if snapshot.period == .day {
            let count = "\(snapshot.sessionCount) \(snapshot.sessionCount == 1 ? "session" : "sessions")"
            let remaining = max(0, Int(ceil(Double(snapshot.goalMinutes * 60) - snapshot.totalSeconds)))
            return remaining == 0 ? "\(count) · Daily goal reached"
                : "\(count) · \(Int(ceil(Double(remaining) / 60))) min to your daily goal"
        }
        return "Daily average \(StudyTime.duration(snapshot.averageSeconds)) · Goal \(StudyTime.duration(Double(snapshot.goalMinutes * 60)))"
    }
}
