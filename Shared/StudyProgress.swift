import Foundation

nonisolated struct StudyDayValue: Identifiable, Equatable, Sendable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
}

nonisolated struct HomeStudyMetrics: Equatable, Sendable {
    let todaySeconds: TimeInterval
    let goalMinutes: Int
    let streak: Int
    let days: [StudyDayValue]
    let weekSeconds: TimeInterval

    var progress: Double { min(1, max(0, todaySeconds / Double(goalMinutes * 60))) }
    var goalMessage: String {
        let remaining = max(0, Int(ceil(Double(goalMinutes * 60) - todaySeconds)))
        if remaining == 0 { return "Daily goal reached. A little focus adds up." }
        return "\(Int(ceil(Double(remaining) / 60))) minutes to your daily goal"
    }
}

// Shared by the app and widget so daily totals, paused time and streak rules agree.
nonisolated enum StudyProgress {
    static func mergedRanges(_ ranges: [DateInterval]) -> [DateInterval] {
        let sorted = ranges.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var result: [DateInterval] = []
        for range in sorted {
            guard let last = result.last else { result.append(range); continue }
            if range.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, range.end))
            } else { result.append(range) }
        }
        return result
    }

    static func dailyTotals(ranges: [DateInterval], calendar: Calendar) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for range in ranges {
            var cursor = range.start
            while cursor < range.end {
                guard let day = calendar.dateInterval(of: .day, for: cursor), day.end > cursor else { break }
                let end = min(day.end, range.end)
                totals[day.start, default: 0] += end.timeIntervalSince(cursor)
                cursor = end
            }
        }
        return totals
    }

    static func metrics(totals: [Date: TimeInterval], now: Date, calendar: Calendar,
                        rollingWeek: Bool = false, goal: (Date) -> Int) -> HomeStudyMetrics {
        let today = calendar.startOfDay(for: now)
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        weekCalendar.minimumDaysInFirstWeek = 4
        let start = rollingWeek
            ? calendar.date(byAdding: .day, value: -6, to: today) ?? today
            : weekCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let days = (0..<7).compactMap { offset -> StudyDayValue? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return StudyDayValue(date: date, seconds: totals[date] ?? 0)
        }
        return HomeStudyMetrics(todaySeconds: totals[today] ?? 0, goalMinutes: max(1, goal(now)),
                                streak: streak(totals: totals, now: now, calendar: calendar, goal: goal).count,
                                days: days, weekSeconds: days.reduce(0) { $0 + $1.seconds })
    }

    static func streak(totals: [Date: TimeInterval], now: Date, calendar: Calendar,
                       goal: (Date) -> Int) -> (count: Int, lastDay: Date?) {
        let today = calendar.startOfDay(for: now)
        func qualifies(_ day: Date) -> Bool {
            (totals[day] ?? 0) >= Double(max(1, goal(day)) * 60)
        }
        var day = qualifies(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)
        let lastDay = day.flatMap { qualifies($0) ? $0 : nil }
        var count = 0
        while let current = day, qualifies(current) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: current)
        }
        return (count, lastDay)
    }
}
