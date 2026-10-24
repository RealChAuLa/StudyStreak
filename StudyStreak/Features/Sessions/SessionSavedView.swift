import SwiftUI

struct SessionSavedView: View {
    let record: SessionRecord
    var onDone: (() -> Void)?
    @Environment(StudySessionTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("SessionSavedCheck").resizable().scaledToFit().frame(width: 52, height: 52)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 120, height: 120)
                    .background(AppColors.tint, in: Circle())
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
                VStack(spacing: 12) {
                    Text("Time well spent.").font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
                    Text(Calendar.current.isDateInToday(record.endedAt ?? record.startedAt)
                         ? "You showed up for yourself today." : "You made time for what matters.")
                        .font(AppTypography.body).foregroundStyle(AppColors.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
                summary
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 80)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Session saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(onDone == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Done") {
                if let onDone { onDone() } else { dismiss() }
            }
            .padding(24)
            .background(AppColors.background)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(StudyTime.duration(record.elapsed(at: record.endedAt ?? .now)))
                .font(.custom("GoogleSans-Bold", size: 48, relativeTo: .largeTitle))
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.6).lineLimit(1)
            HStack(spacing: 8) {
                SessionSubjectPill(subject: record.subject)
                Text(savedDate)
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            }
            if record.subjectCount > 1 {
                Text("Includes \(record.subjectCount) subjects")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                ForEach(Array(subjectTotals.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Text(item.subject.name).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(StudyTime.duration(item.seconds))
                    }
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                }
            }
            Divider().overlay(AppColors.border)
            Text(progressMessage)
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .studySessionCard()
    }

    private var savedDate: String {
        let date = record.endedAt ?? record.startedAt
        return Calendar.current.isDateInToday(date)
            ? "Saved today" : date.formatted(date: .abbreviated, time: .omitted)
    }

    private var progressMessage: String {
        guard Calendar.current.isDateInToday(record.endedAt ?? record.startedAt) else {
            return "A little focus, saved for your progress."
        }
        let metrics = tracker.metrics(at: .now)
        return "\(metrics.streak)-day streak · \(metrics.goalMessage)"
    }

    private var subjectTotals: [(subject: SessionSubject, seconds: TimeInterval)] {
        var totals: [UUID: (subject: SessionSubject, seconds: TimeInterval)] = [:]
        for span in record.spans {
            let duration = span.range(at: record.endedAt ?? .now)?.duration ?? 0
            let previous = totals[span.subject.id]?.seconds ?? 0
            totals[span.subject.id] = (span.subject, previous + duration)
        }
        return totals.values.sorted { $0.seconds > $1.seconds }
    }
}
