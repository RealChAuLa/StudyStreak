import Foundation

nonisolated enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day = "Day", week = "Week", month = "Month"
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }
}

nonisolated struct StatsBar: Identifiable, Equatable, Sendable {
    let id: Int
    let label: String
    let detail: String
    let seconds: TimeInterval
    let isCurrent: Bool
}

nonisolated struct StatsSubjectTotal: Identifiable, Equatable, Sendable {
    let subject: SessionSubject
    var seconds: TimeInterval
    var id: UUID { subject.id }
}

nonisolated struct StatsZoneTotal: Identifiable, Equatable, Sendable {
    let zoneID: UUID?
    let name: String
    var seconds: TimeInterval
    var id: String { zoneID?.uuidString ?? "not-in-a-zone" }
}

nonisolated struct StatsHeatmapDay: Identifiable, Equatable, Sendable {
    let date: Date
    let seconds: TimeInterval
    let goalMinutes: Int
    let isFuture: Bool
    var id: Date { date }
    var reachedGoal: Bool { !isFuture && seconds >= Double(goalMinutes * 60) }
    var intensity: Double { min(1, seconds / Double(max(1, goalMinutes) * 60)) }
}

nonisolated struct StatsHeatmapWeek: Identifiable, Equatable, Sendable {
    let start: Date
    let monthLabel: String
    let days: [StatsHeatmapDay]
    var id: Date { start }
}

nonisolated struct StatsSnapshot: Equatable, Sendable {
    let period: StatsPeriod
    let title: String
    let totalSeconds: TimeInterval
    let previousSeconds: TimeInterval
    let averageSeconds: TimeInterval
    let goalMinutes: Int
    let sessionCount: Int
    let bars: [StatsBar]
    let subjects: [StatsSubjectTotal]
    let zones: [StatsZoneTotal]
    let weeks: [StatsHeatmapWeek]

    var comparisonPercent: Int? {
        guard previousSeconds >= 1 else { return nil }
        return Int(((totalSeconds - previousSeconds) / previousSeconds * 100).rounded())
    }
}

// Reads immutable session snapshots only; statistics never write to SwiftData or Firebase.
nonisolated enum StatsAnalytics {
    private nonisolated struct Segment {
        let sessionID: UUID
        let subject: SessionSubject
        let zoneID: UUID?
        let zoneName: String?
        let range: DateInterval
    }

    static func snapshot(records: [SessionRecord], period: StatsPeriod, now: Date,
                         calendar: Calendar = .current, goal: (Date) -> Int) -> StatsSnapshot {
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let today = calendar.startOfDay(for: now)
        let interval = calendar.dateInterval(of: period.component, for: now)
            ?? DateInterval(start: today, end: now)

        let ranges = SessionAnalytics.mergedRanges(records: records, now: now)
        let daily = SessionAnalytics.dailyTotals(ranges: ranges, calendar: calendar)
        let segments = attributedSegments(records: records, now: now)
        let selected = segments.compactMap { segment -> Segment? in
            guard let clipped = intersection(segment.range, interval) else { return nil }
            return Segment(sessionID: segment.sessionID, subject: segment.subject,
                           zoneID: segment.zoneID, zoneName: segment.zoneName, range: clipped)
        }
        let total = seconds(in: interval, ranges: ranges)
        let elapsedDays = max(1, (calendar.dateComponents([.day], from: interval.start, to: today).day ?? 0) + 1)

        // Compare the same local point in the preceding period, not a partial week against a full week.
        let previousDate = calendar.date(byAdding: period.component, value: -1, to: now) ?? now
        let previous = calendar.dateInterval(of: period.component, for: previousDate)
        let previousSeconds = previous.map {
            seconds(in: DateInterval(start: $0.start, end: min($0.end, max($0.start, previousDate))), ranges: ranges)
        } ?? 0

        return StatsSnapshot(
            period: period, title: periodTitle(period, interval: interval, now: now, calendar: calendar),
            totalSeconds: total, previousSeconds: previousSeconds,
            averageSeconds: total / Double(elapsedDays), goalMinutes: max(1, goal(now)),
            sessionCount: Set(selected.map(\.sessionID)).count,
            bars: bars(period: period, interval: interval, segments: selected,
                       ranges: ranges, now: now, calendar: calendar),
            subjects: subjectTotals(selected), zones: zoneTotals(selected),
            weeks: heatmap(daily: daily, now: now, calendar: calendar, goal: goal)
        )
    }

    // First-started intervals own any overlap. This retains the dashboard's union of study time
    // while making subject and zone totals add up to exactly the same total.
    private static func attributedSegments(records: [SessionRecord], now: Date) -> [Segment] {
        let sorted = records.flatMap { record in
            record.spans.compactMap { span -> Segment? in
                guard let range = span.range(at: min(record.endedAt ?? now, now)) else { return nil }
                return Segment(sessionID: record.id, subject: span.subject, zoneID: record.zoneID,
                               zoneName: record.zoneName, range: range)
            }
        }.sorted {
            if $0.range.start != $1.range.start { return $0.range.start < $1.range.start }
            if $0.sessionID != $1.sessionID { return $0.sessionID.uuidString < $1.sessionID.uuidString }
            return $0.subject.id.uuidString < $1.subject.id.uuidString
        }
        var result: [Segment] = []
        var coveredUntil = Date.distantPast
        for segment in sorted {
            let start = max(segment.range.start, coveredUntil)
            guard segment.range.end > start else { continue }
            result.append(Segment(sessionID: segment.sessionID, subject: segment.subject,
                                  zoneID: segment.zoneID, zoneName: segment.zoneName,
                                  range: DateInterval(start: start, end: segment.range.end)))
            coveredUntil = segment.range.end
        }
        return result
    }

    private static func subjectTotals(_ segments: [Segment]) -> [StatsSubjectTotal] {
        var result: [UUID: StatsSubjectTotal] = [:]
        for segment in segments {
            let seconds = (result[segment.subject.id]?.seconds ?? 0) + segment.range.duration
            result[segment.subject.id] = StatsSubjectTotal(subject: segment.subject, seconds: seconds)
        }
        return result.values.sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            if $0.subject.name != $1.subject.name { return $0.subject.name < $1.subject.name }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private static func zoneTotals(_ segments: [Segment]) -> [StatsZoneTotal] {
        var result: [String: StatsZoneTotal] = [:]
        for segment in segments {
            let key = segment.zoneID?.uuidString ?? "not-in-a-zone"
            let name = segment.zoneID == nil ? "Not in a zone" : (segment.zoneName ?? "Study zone")
            let seconds = (result[key]?.seconds ?? 0) + segment.range.duration
            result[key] = StatsZoneTotal(zoneID: segment.zoneID, name: name, seconds: seconds)
        }
        return result.values.sorted {
            if $0.seconds != $1.seconds { return $0.seconds > $1.seconds }
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.id < $1.id
        }
    }

    private static func bars(period: StatsPeriod, interval: DateInterval, segments: [Segment],
                             ranges: [DateInterval], now: Date, calendar: Calendar) -> [StatsBar] {
        if period == .day {
            let groups = Dictionary(grouping: segments, by: \.sessionID).values.sorted {
                ($0.map(\.range.start).min() ?? now) < ($1.map(\.range.start).min() ?? now)
            }
            return groups.enumerated().map { index, group in
                let start = group.map(\.range.start).min() ?? now
                let time = dateLabel(start, template: "jmm", calendar: calendar)
                return StatsBar(id: index, label: time, detail: "Session at \(time)",
                                seconds: group.reduce(0) { $0 + $1.range.duration },
                                isCurrent: index == groups.count - 1)
            }
        }
        var result: [StatsBar] = []
        var cursor = interval.start
        while cursor < interval.end {
            let next = min(interval.end, calendar.date(byAdding: .day, value: period == .week ? 1 : 7, to: cursor)
                           ?? interval.end)
            guard next > cursor else { break }
            let range = DateInterval(start: cursor, end: next)
            let lastDay = calendar.date(byAdding: .day, value: -1, to: next) ?? cursor
            let label = period == .week
                ? dateLabel(cursor, template: "EEEEE", calendar: calendar)
                : "\(calendar.component(.day, from: cursor))–\(calendar.component(.day, from: lastDay))"
            let detail = period == .week
                ? dateLabel(cursor, template: "EEE d MMM", calendar: calendar)
                : "\(dateLabel(cursor, template: "d MMM", calendar: calendar)) – \(dateLabel(lastDay, template: "d MMM", calendar: calendar))"
            result.append(StatsBar(id: result.count, label: label, detail: detail,
                                   seconds: seconds(in: range, ranges: ranges),
                                   isCurrent: cursor <= now && now < next))
            cursor = next
        }
        return result
    }

    private static func heatmap(daily: [Date: TimeInterval], now: Date, calendar: Calendar,
                                goal: (Date) -> Int) -> [StatsHeatmapWeek] {
        let today = calendar.startOfDay(for: now)
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let start = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeek) ?? thisWeek
        var previousMonth: Int?
        return (0..<12).compactMap { weekIndex in
            guard let week = calendar.date(byAdding: .day, value: weekIndex * 7, to: start) else { return nil }
            let month = calendar.component(.month, from: week)
            let label = previousMonth != month ? dateLabel(week, template: "MMM", calendar: calendar).uppercased() : ""
            previousMonth = month
            let days = (0..<7).compactMap { dayIndex -> StatsHeatmapDay? in
                guard let day = calendar.date(byAdding: .day, value: dayIndex, to: week) else { return nil }
                return StatsHeatmapDay(date: day, seconds: daily[day] ?? 0,
                                       goalMinutes: max(1, goal(day)), isFuture: day > today)
            }
            return StatsHeatmapWeek(start: week, monthLabel: label, days: days)
        }
    }

    private static func periodTitle(_ period: StatsPeriod, interval: DateInterval,
                                    now: Date, calendar: Calendar) -> String {
        switch period {
        case .day: return "TODAY · \(dateLabel(now, template: "d MMM", calendar: calendar).uppercased())"
        case .month: return dateLabel(now, template: "MMMM yyyy", calendar: calendar).uppercased()
        case .week:
            let formatter = DateIntervalFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = calendar.locale ?? .current
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            return formatter.string(from: interval.start, to: last).uppercased()
        }
    }

    private static func dateLabel(_ date: Date, template: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private static func seconds(in interval: DateInterval, ranges: [DateInterval]) -> TimeInterval {
        ranges.reduce(0) { $0 + (intersection($1, interval)?.duration ?? 0) }
    }

    private static func intersection(_ lhs: DateInterval, _ rhs: DateInterval) -> DateInterval? {
        let start = max(lhs.start, rhs.start)
        let end = min(lhs.end, rhs.end)
        return end > start ? DateInterval(start: start, end: end) : nil
    }
}
