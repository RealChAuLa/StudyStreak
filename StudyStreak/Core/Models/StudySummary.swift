import Foundation

nonisolated enum LeaderboardPeriod: String, CaseIterable, Identifiable, Sendable {
    case thisWeek = "This Week"
    case allTime = "All Time"
    var id: String { rawValue }
}

// A projection of completed session data. Raw sessions and zone coordinates stay local.
nonisolated struct StudySummary: Equatable, Sendable {
    let weekID: String
    let weekSeconds: Int
    let totalSeconds: Int
    let streak: Int
    let streakDay: String
    let timeZoneID: String

    var isValid: Bool {
        weekID.range(of: #"^\d{4}-W(0[1-9]|[1-4][0-9]|5[0-3])$"#, options: .regularExpression) != nil
            && (0...604_800).contains(weekSeconds)
            && totalSeconds >= weekSeconds && streak >= 0
            && TimeZone(identifier: timeZoneID) != nil
            && ((streak == 0 && streakDay.isEmpty) || (streak > 0 && validDay))
    }

    func seconds(for period: LeaderboardPeriod, now: Date) -> Int {
        switch period {
        case .thisWeek: weekID == Self.weekID(for: now) ? weekSeconds : 0
        case .allTime: totalSeconds
        }
    }

    func currentStreak(now: Date) -> Int {
        guard streak > 0, let zone = TimeZone(identifier: timeZoneID) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let days = [Self.dayID(for: now, timeZone: zone), Self.dayID(for: yesterday, timeZone: zone)]
        return days.contains(streakDay) ? streak : 0
    }

    // All friends use the same Monday-to-Monday UTC week for comparable rankings.
    static func weekID(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    static func dayID(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private var validDay: Bool {
        guard streakDay.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
              let zone = TimeZone(identifier: timeZoneID) else { return false }
        let values = streakDay.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let date = calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2])) else { return false }
        return Self.dayID(for: date, timeZone: zone) == streakDay
    }
}

nonisolated struct LeaderboardEntry: Identifiable, Equatable, Sendable {
    let profile: FriendProfile
    let seconds: Int?
    let streak: Int?
    let isCurrentUser: Bool
    let isPrivate: Bool
    var rank: Int?
    var id: String { profile.id }

    var duration: String {
        guard let seconds else { return "—" }
        let minutes = seconds / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    var streakDescription: String {
        if isPrivate { return "You · Private" }
        let value = streak.map { "\($0) day streak" } ?? "No study data yet"
        return isCurrentUser ? "You · \(value)" : value
    }

    static func ranked(_ entries: [Self]) -> [Self] {
        let ordered = entries.sorted { left, right in
            let lhs = left.isPrivate ? nil : left.seconds
            let rhs = right.isPrivate ? nil : right.seconds
            if lhs != rhs { return (lhs ?? -1) > (rhs ?? -1) }
            if left.profile.username != right.profile.username {
                return left.profile.username < right.profile.username
            }
            return left.id < right.id
        }
        var lastSeconds: Int?
        var lastRank = 0
        var position = 0
        return ordered.map { entry in
            var value = entry
            value.rank = nil
            if let seconds = entry.seconds, !entry.isPrivate {
                position += 1
                if lastSeconds != seconds { lastRank = position }
                value.rank = lastRank
                lastSeconds = seconds
            }
            return value
        }
    }
}
