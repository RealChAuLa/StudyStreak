import Foundation

nonisolated enum SessionAnalytics {
    static func dashboard(records: [SessionRecord], now: Date, calendar: Calendar = .current,
                          goal: (Date) -> Int) -> HomeStudyMetrics {
        let ranges = mergedRanges(records: records, now: now)
        let totals = dailyTotals(ranges: ranges, calendar: calendar)
        return StudyProgress.metrics(totals: totals, now: now, calendar: calendar, goal: goal)
    }

    static func summary(records: [SessionRecord], now: Date, calendar: Calendar = .current,
                        goal: (Date) -> Int) -> StudySummary {
        // Public rankings use completed sessions; the Home dashboard also includes the live session.
        let ranges = mergedRanges(records: records.filter { $0.state == .completed }, now: now)
        let totals = dailyTotals(ranges: ranges, calendar: calendar)
        let currentStreak = StudyProgress.streak(totals: totals, now: now, calendar: calendar, goal: goal)
        var utc = Calendar(identifier: .iso8601)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let week = utc.dateInterval(of: .weekOfYear, for: now)!
        let weekly = ranges.reduce(0.0) { $0 + overlap($1, with: week) }
        let total = ranges.reduce(0.0) { $0 + $1.duration }
        return StudySummary(
            weekID: StudySummary.weekID(for: now), weekSeconds: min(604_800, Int(weekly)),
            totalSeconds: Int(total), streak: currentStreak.count,
            streakDay: currentStreak.lastDay.map { StudySummary.dayID(for: $0, timeZone: calendar.timeZone) } ?? "",
            timeZoneID: calendar.timeZone.identifier
        )
    }

    static func mergedRanges(records: [SessionRecord], now: Date,
                             includeOpenIntervals: Bool = true) -> [DateInterval] {
        let ranges = records.flatMap { record in
            record.spans.compactMap { span -> DateInterval? in
                guard includeOpenIntervals || span.endedAt != nil else { return nil }
                return span.range(at: min(record.endedAt ?? now, now))
            }
        }
        return StudyProgress.mergedRanges(ranges)
    }

    private static func overlap(_ range: DateInterval, with other: DateInterval) -> TimeInterval {
        max(0, min(range.end, other.end).timeIntervalSince(max(range.start, other.start)))
    }

    static func dailyTotals(ranges: [DateInterval], calendar: Calendar) -> [Date: TimeInterval] {
        StudyProgress.dailyTotals(ranges: ranges, calendar: calendar)
    }
}
