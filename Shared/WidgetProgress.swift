import Foundation

nonisolated enum StudyWidgetConfiguration {
    static let kind = "StudyStreakProgress"
    static let homeURL = URL(string: "studystreak://home")!

    static func opensHome(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "studystreak" && url.host?.lowercased() == "home"
            && (url.path.isEmpty || url.path == "/")
    }
}

nonisolated enum WidgetProgressState: String, Codable, Sendable {
    case available, signedOut, unavailable
}

nonisolated struct WidgetStudyRange: Codable, Equatable, Sendable {
    let start: Date
    let end: Date
}

nonisolated struct WidgetGoalChange: Codable, Equatable, Sendable {
    let effectiveFrom: Date
    let minutes: Int
}

// Only anonymous time ranges and goal history cross the app boundary.
// The widget never opens the study database, authenticates, or receives zone coordinates.
nonisolated struct WidgetProgressSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1
    let version: Int
    let state: WidgetProgressState
    let generatedAt: Date
    let ranges: [WidgetStudyRange]
    let runningSince: Date?
    let goals: [WidgetGoalChange]

    static func empty(_ state: WidgetProgressState, now: Date = .now) -> Self {
        Self(version: currentVersion, state: state, generatedAt: now,
             ranges: [], runningSince: nil, goals: [])
    }

    func hasSameProgress(as other: Self) -> Bool {
        version == other.version && state == other.state && ranges == other.ranges
            && runningSince == other.runningSince && goals == other.goals
    }
}

nonisolated struct WidgetProgressProjection {
    private let snapshot: WidgetProgressSnapshot
    private let calendar: Calendar
    private let closedTotals: [Date: TimeInterval]
    private let closedRanges: [DateInterval]
    private let lastClosedEnd: Date?

    init(snapshot: WidgetProgressSnapshot, calendar: Calendar = .current) {
        self.snapshot = snapshot
        self.calendar = calendar
        let ranges = StudyProgress.mergedRanges(snapshot.ranges.compactMap {
            let end = min($0.end, snapshot.generatedAt)
            return end > $0.start ? DateInterval(start: $0.start, end: end) : nil
        })
        closedRanges = ranges
        closedTotals = StudyProgress.dailyTotals(ranges: ranges, calendar: calendar)
        lastClosedEnd = ranges.last?.end
    }

    func metrics(at date: Date) -> HomeStudyMetrics {
        var totals = closedTotals
        // A clock correction or older overlapping data still follows the app's union-of-time rule.
        let runningOverlaps = snapshot.runningSince.map { $0 < (lastClosedEnd ?? $0) } ?? false
        if date < snapshot.generatedAt || runningOverlaps {
            var ranges = closedRanges.compactMap { range -> DateInterval? in
                let end = min(range.end, date)
                return end > range.start ? DateInterval(start: range.start, end: end) : nil
            }
            if let running = snapshot.runningSince, date > running {
                ranges.append(DateInterval(start: running, end: date))
            }
            totals = StudyProgress.dailyTotals(ranges: StudyProgress.mergedRanges(ranges), calendar: calendar)
        } else if let running = snapshot.runningSince, date > running {
            let runningTotals = StudyProgress.dailyTotals(
                ranges: [DateInterval(start: running, end: date)], calendar: calendar)
            for (day, seconds) in runningTotals { totals[day, default: 0] += seconds }
        }
        return StudyProgress.metrics(totals: totals, now: date, calendar: calendar,
                                     rollingWeek: true, goal: goal(on:))
    }

    func goal(on date: Date) -> Int {
        max(1, snapshot.goals.filter { $0.effectiveFrom <= date }
            .max { $0.effectiveFrom < $1.effectiveFrom }?.minutes ?? 120)
    }

    func timelineDates(from now: Date) -> [Date] {
        var dates = [now]
        if snapshot.runningSince != nil {
            // These are prepared entries, not repeated requests to wake the extension.
            dates += (1...96).map { now.addingTimeInterval(Double($0) * 15 * 60) }
            let today = metrics(at: now)
            let remaining = Double(today.goalMinutes * 60) - today.todaySeconds
            if remaining > 0,
               let day = calendar.dateInterval(of: .day, for: now),
               now.addingTimeInterval(remaining) < day.end {
                dates.append(now.addingTimeInterval(remaining))
            }
        }
        let today = calendar.startOfDay(for: now)
        for offset in 1...2 {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.append(midnight)
            }
        }
        return Array(Set(dates)).sorted()
    }
}

nonisolated enum WidgetProgressStoreError: Error {
    case missingAppGroup, unsupportedVersion
}

nonisolated enum WidgetProgressStore {
    static func read() throws -> WidgetProgressSnapshot? {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(WidgetProgressSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.version == WidgetProgressSnapshot.currentVersion else {
            throw WidgetProgressStoreError.unsupportedVersion
        }
        return snapshot
    }

    static func write(_ snapshot: WidgetProgressSnapshot) throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private static func fileURL() throws -> URL {
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "StudyStreakAppGroup") as? String,
              !identifier.isEmpty, !identifier.contains("$("),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw WidgetProgressStoreError.missingAppGroup
        }
        return container.appendingPathComponent("StudyStreak", isDirectory: true)
            .appendingPathComponent("widget-progress-v1.json")
    }
}
