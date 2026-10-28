import Foundation
import SwiftData

@MainActor
enum StudyBackupService {
    static func export(container: ModelContainer, tracker: StudySessionTracker) throws -> StudyBackup {
        let context = ModelContext(container)
        let ownerID = tracker.ownerID
        let subjects = try context.fetch(FetchDescriptor<StudySubject>(
            predicate: #Predicate { $0.ownerID == ownerID }, sortBy: [SortDescriptor(\.sortIndex)]))
        let zones = try context.fetch(FetchDescriptor<StudyZone>(
            predicate: #Predicate { $0.ownerID == ownerID }))
        let backup = StudyBackup(format: "StudyStreak", version: 1, ownerID: ownerID, exportedAt: .now,
            subjects: subjects.map {
                StudyBackup.Subject(id: $0.id, name: $0.name, colorID: $0.colorID, iconID: $0.iconID,
                    sortIndex: $0.sortIndex, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }, zones: zones.map {
                StudyBackup.Zone(id: $0.id, name: $0.name, latitude: $0.latitude, longitude: $0.longitude,
                    radiusMeters: $0.radiusMeters, address: $0.address, iconID: $0.iconID,
                    subjectID: $0.defaultSubject?.id, isEnabled: $0.isEnabled,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }, sessions: tracker.history, goals: RoutinePreferences(ownerID: ownerID).settings.goals)
        try backup.validate()
        return backup
    }

    static func restore(_ backup: StudyBackup, ownerID: String, container: ModelContainer) throws {
        try backup.validate()
        guard backup.ownerID == ownerID else { throw StudyBackupError.wrongAccount }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let subjects = try context.fetch(FetchDescriptor<StudySubject>())
        let zones = try context.fetch(FetchDescriptor<StudyZone>())
        let sessions = try context.fetch(FetchDescriptor<StudySession>())
        guard !sessions.contains(where: { $0.ownerID == ownerID && $0.stateRaw != "completed" }) else {
            throw StudyBackupError.activeSession
        }
        let subjectIDs = Set(backup.subjects.map(\.id))
        let zoneIDs = Set(backup.zones.map(\.id))
        let sessionIDs = Set(backup.sessions.map(\.id))
        // IDs are unique across the local store. Never upsert another account's records.
        guard !subjects.contains(where: { $0.ownerID != ownerID && subjectIDs.contains($0.id) }),
              !zones.contains(where: { $0.ownerID != ownerID && zoneIDs.contains($0.id) }),
              !sessions.contains(where: { $0.ownerID != ownerID && sessionIDs.contains($0.id) }) else {
            throw StudyBackupError.wrongAccount
        }
        var subjectMap = Dictionary(uniqueKeysWithValues: subjects.filter { $0.ownerID == ownerID }.map { ($0.id, $0) })
        let zoneMap = Dictionary(uniqueKeysWithValues: zones.filter { $0.ownerID == ownerID }.map { ($0.id, $0) })
        let sessionMap = Dictionary(uniqueKeysWithValues: sessions.filter { $0.ownerID == ownerID }.map { ($0.id, $0) })
        do {
            for saved in backup.subjects {
                let subject = subjectMap[saved.id] ?? StudySubject(ownerID: ownerID, name: saved.name,
                    colorID: saved.colorID, iconID: saved.iconID, sortIndex: saved.sortIndex)
                if subjectMap[saved.id] == nil { context.insert(subject) }
                subject.id = saved.id
                subject.name = saved.name
                subject.colorID = saved.colorID
                subject.iconID = saved.iconID
                subject.sortIndex = saved.sortIndex
                subject.isActive = saved.isActive
                subject.createdAt = saved.createdAt
                subject.updatedAt = saved.updatedAt
                subjectMap[saved.id] = subject
            }
            for saved in backup.zones {
                let zone = zoneMap[saved.id] ?? StudyZone(ownerID: ownerID, name: saved.name,
                    latitude: saved.latitude, longitude: saved.longitude, radiusMeters: saved.radiusMeters,
                    iconID: saved.iconID)
                if zoneMap[saved.id] == nil { context.insert(zone) }
                zone.id = saved.id
                zone.name = saved.name
                zone.latitude = saved.latitude
                zone.longitude = saved.longitude
                zone.radiusMeters = saved.radiusMeters
                zone.address = saved.address
                zone.iconID = saved.iconID
                zone.defaultSubject = saved.subjectID.flatMap { subjectMap[$0] }
                zone.isEnabled = saved.isEnabled
                zone.createdAt = saved.createdAt
                zone.updatedAt = saved.updatedAt
            }
            for saved in backup.sessions {
                let session = sessionMap[saved.id] ?? StudySession(ownerID: ownerID, subject: saved.subject,
                    zoneID: saved.zoneID, zoneName: saved.zoneName, now: saved.startedAt)
                if sessionMap[saved.id] == nil { context.insert(session) }
                session.id = saved.id
                session.startedAt = saved.startedAt
                session.endedAt = saved.endedAt
                session.stateRaw = SessionState.completed.rawValue
                session.sourceRaw = saved.source
                session.subjectID = saved.subject.id
                session.subjectName = saved.subject.name
                session.subjectColorID = saved.subject.colorID
                session.subjectIconID = saved.subject.iconID
                session.zoneID = saved.zoneID
                session.zoneName = saved.zoneName
                session.pauseReasonRaw = nil
                session.needsSubjectConfirmation = false
                session.confirmationExpiresAt = nil
                let oldIntervals = session.intervals
                session.intervals = []
                for interval in oldIntervals { context.delete(interval) }
                for span in saved.spans {
                    let interval = StudyInterval(subject: span.subject, now: span.startedAt)
                    interval.endedAt = span.endedAt
                    context.insert(interval)
                    session.intervals.append(interval)
                }
            }
            for session in sessions where session.ownerID == ownerID && !sessionIDs.contains(session.id) { context.delete(session) }
            for zone in zones where zone.ownerID == ownerID && !zoneIDs.contains(zone.id) { context.delete(zone) }
            for subject in subjects where subject.ownerID == ownerID && !subjectIDs.contains(subject.id) { context.delete(subject) }
            // One save: a failed import rolls back the replacement, including deletions.
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        let preferences = RoutinePreferences(ownerID: ownerID)
        preferences.settings.goals = backup.goals
    }
}
