import Foundation
import WidgetKit

nonisolated struct StudyProgressEntry: TimelineEntry {
    let date: Date
    let state: WidgetProgressState
    let metrics: HomeStudyMetrics?

    static func preview(at date: Date = .now) -> Self {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let values: [TimeInterval] = [5760, 8640, 6000, 11520, 7680, 6960, 5400]
        let days = (0..<7).compactMap { offset -> StudyDayValue? in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return StudyDayValue(date: day, seconds: values[offset])
        }
        return Self(date: date, state: .available,
                    metrics: HomeStudyMetrics(todaySeconds: 5400, goalMinutes: 120, streak: 12,
                                              days: days, weekSeconds: values.reduce(0, +)))
    }
}

nonisolated struct StudyProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudyProgressEntry { .preview() }

    func getSnapshot(in context: Context, completion: @escaping (StudyProgressEntry) -> Void) {
        let now = Date.now
        if context.isPreview { completion(.preview(at: now)); return }
        guard let snapshot = load() else {
            completion(StudyProgressEntry(date: now, state: .unavailable, metrics: nil))
            return
        }
        let projection = WidgetProgressProjection(snapshot: snapshot)
        completion(entry(snapshot: snapshot, projection: projection, at: now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyProgressEntry>) -> Void) {
        let now = Date.now
        guard let snapshot = load() else {
            completion(Timeline(entries: [StudyProgressEntry(date: now, state: .unavailable, metrics: nil)],
                                policy: .after(now.addingTimeInterval(3600))))
            return
        }
        guard snapshot.state == .available else {
            completion(Timeline(entries: [StudyProgressEntry(date: now, state: snapshot.state, metrics: nil)],
                                policy: snapshot.state == .signedOut ? .never : .after(now.addingTimeInterval(3600))))
            return
        }
        let projection = WidgetProgressProjection(snapshot: snapshot)
        let entries = projection.timelineDates(from: now).map {
            entry(snapshot: snapshot, projection: projection, at: $0)
        }
        let refresh = now.addingTimeInterval(snapshot.runningSince == nil ? 3600 : 1800)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func entry(snapshot: WidgetProgressSnapshot, projection: WidgetProgressProjection,
                       at date: Date) -> StudyProgressEntry {
        StudyProgressEntry(date: date, state: snapshot.state,
                           metrics: snapshot.state == .available ? projection.metrics(at: date) : nil)
    }

    private func load() -> WidgetProgressSnapshot? {
        // The containing app is the only writer; reads see an entire atomic snapshot.
        try? WidgetProgressStore.read()
    }
}
