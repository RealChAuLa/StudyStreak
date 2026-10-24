import Foundation

nonisolated enum SessionState: String, Codable, Sendable {
    case running, paused, completed
}

nonisolated enum SessionPauseReason: String, Codable, Sendable {
    case user, zoneExit, permission, zoneUnavailable, signedOut, trackingDisabled
}

nonisolated enum SessionSource: String, Sendable { case manual, automatic }

nonisolated struct SessionSubject: Equatable, Sendable {
    let id: UUID
    let name: String
    let colorID: String
    let iconID: String
}

nonisolated struct SessionSpan: Equatable, Sendable {
    let startedAt: Date
    let endedAt: Date?
    let subject: SessionSubject

    func range(at now: Date) -> DateInterval? {
        let end = min(endedAt ?? now, now)
        guard end > startedAt else { return nil }
        return DateInterval(start: startedAt, end: end)
    }
}

nonisolated struct SessionRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let state: SessionState
    let subject: SessionSubject
    let zoneID: UUID?
    let zoneName: String?
    let source: String
    let spans: [SessionSpan]
    var pauseReason: SessionPauseReason? = nil
    var needsSubjectConfirmation = false
    var confirmationExpiresAt: Date? = nil
    var isAutomatic: Bool { source == SessionSource.automatic.rawValue }

    func elapsed(at now: Date) -> TimeInterval {
        spans.compactMap { $0.range(at: min(endedAt ?? now, now)) }.reduce(0) { $0 + $1.duration }
    }

    var subjectCount: Int { Set(spans.map(\.subject.id)).count }
    var historyTitle: String {
        subjectCount > 1 ? "\(subject.name) + \(subjectCount - 1)" : subject.name
    }
}

nonisolated enum StudyTime {
    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        if value > 0 && value < 60 { return "<1 min" }
        let minutes = value / 60
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }
}
