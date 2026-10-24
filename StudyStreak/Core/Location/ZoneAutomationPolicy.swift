import Foundation

nonisolated enum ZonePresence: String, Codable, Sendable {
    case unknown, inside, outside
}

nonisolated struct MonitoredStudyZone: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: String
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let subjectID: UUID
    let createdAt: Date

    var regionIdentifier: String { "StudyStreak.zone.\(ownerID).\(id.uuidString)" }
}

nonisolated enum ZoneAutomationAction: Equatable, Sendable {
    case none
    case start(UUID)
    case resume
    case pause
    case switchZone(UUID)
}

nonisolated enum ZoneAutomationPolicy {
    static func action(zoneID: UUID, presence: ZonePresence, current: SessionRecord?,
                       inside: Set<UUID>, suppressed: Set<UUID>, now: Date = .now,
                       calendar: Calendar = .current) -> ZoneAutomationAction {
        if presence == .outside {
            if let current, current.isAutomatic, current.zoneID == zoneID, current.state == .running {
                return .pause
            }
            return .none
        }
        guard presence == .inside, !suppressed.contains(zoneID) else { return .none }
        guard let current else { return .start(zoneID) }
        // A manual session or a deliberate pause keeps priority over location events.
        guard current.isAutomatic, current.state == .paused,
              current.pauseReason != nil, current.pauseReason != .user else { return .none }
        if current.zoneID == zoneID {
            if let last = current.spans.compactMap(\.endedAt).max(), !calendar.isDate(last, inSameDayAs: now) {
                return .switchZone(zoneID)
            }
            return .resume
        }
        guard current.zoneID.map({ !inside.contains($0) }) ?? true else { return .none }
        return .switchZone(zoneID)
    }
}
