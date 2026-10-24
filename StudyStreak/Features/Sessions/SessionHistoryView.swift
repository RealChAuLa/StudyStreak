import SwiftUI

struct SessionHistoryView: View {
    @Environment(StudySessionTracker.self) private var tracker

    var body: some View {
        Group {
            if tracker.history.isEmpty {
                ContentUnavailableView("A little focus starts here", systemImage: "book",
                                       description: Text("Your completed sessions will appear here."))
            } else {
                List(tracker.history) { record in
                    NavigationLink {
                        SessionSavedView(record: record)
                    } label: {
                        SessionHistoryRow(record: record)
                    }
                    .listRowBackground(AppColors.surface)
                    .listRowSeparatorTint(AppColors.border)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Your sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

struct SessionHistoryRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(record.subject.color).frame(width: 4, height: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.historyTitle)
                    .font(AppTypography.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(record.zoneName ?? "Not in a zone") · \(dateLabel)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(StudyTime.duration(record.elapsed(at: record.endedAt ?? .now)))
                .font(AppTypography.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.text)
                .fixedSize()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private var dateLabel: String {
        Calendar.current.isDateInToday(record.startedAt)
            ? record.startedAt.formatted(date: .omitted, time: .shortened)
            : record.startedAt.formatted(date: .abbreviated, time: .shortened)
    }
}
