import Foundation

// Only small values cross devices. The iPhone keeps the SwiftData models.
nonisolated struct WatchSubject: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
}

nonisolated struct WatchStudySession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let subject: WatchSubject
    let elapsedSeconds: TimeInterval
    let isRunning: Bool
    let measuredAt: Date

    func elapsed(at date: Date) -> TimeInterval {
        elapsedSeconds + (isRunning ? max(0, date.timeIntervalSince(measuredAt)) : 0)
    }
}

nonisolated struct WatchSessionSnapshot: Codable, Equatable, Sendable {
    enum Access: String, Codable, Sendable { case ready, signInRequired, unavailable }

    let accountID: String?
    let generatedAt: Date
    let access: Access
    let subjects: [WatchSubject]
    let current: WatchStudySession?

    static func unavailable(_ access: Access = .unavailable) -> Self {
        Self(accountID: nil, generatedAt: .now, access: access, subjects: [], current: nil)
    }
}

nonisolated enum WatchSessionAction: String, Codable, Sendable {
    case status, start, stop
}

nonisolated struct WatchSessionRequest: Codable, Sendable {
    var id = UUID()
    let action: WatchSessionAction
    let accountID: String?
    var subjectID: UUID? = nil
    var sessionID: UUID? = nil
    var createdAt = Date.now
}

nonisolated struct WatchSessionReply: Codable, Sendable {
    let snapshot: WatchSessionSnapshot
    var completed: WatchStudySession? = nil
    var message: String? = nil
}

nonisolated enum WatchSessionMessage {
    static let dataKey = "studyStreakSession"
}

