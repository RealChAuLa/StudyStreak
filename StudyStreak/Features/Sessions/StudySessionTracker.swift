import FirebaseAuth
import FirebaseCore
import Foundation
import Observation
import SwiftData

nonisolated enum SessionTrackingError: LocalizedError {
    case alreadyRunning, noSession, unavailableSubject, unavailableZone, unreadableStore

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Finish your current session before starting another."
        case .noSession: "There isn’t an active session to change."
        case .unavailableSubject: "Choose one of your active subjects."
        case .unavailableZone: "This study zone is no longer available. Choose another zone."
        case .unreadableStore: "Couldn’t open your study sessions. Please try again."
        }
    }

    static func message(for error: Error) -> String {
        if let error = error as? SessionTrackingError { return error.localizedDescription }
        return "Couldn’t save your session. Please try again."
    }
}

@MainActor
@Observable
final class StudySessionTracker {
    let ownerID: String
    private(set) var current: SessionRecord?
    private(set) var history: [SessionRecord] = []
    private(set) var loadError: String?
    private(set) var syncError: String?
    private(set) var settings: RoutineSettings
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var models: [StudySession] = []
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var needsSync = false

    init(container: ModelContainer, ownerID: String) {
        self.container = container
        self.ownerID = ownerID
        // Commit each action explicitly, with a context that cannot roll back an editor's changes.
        let sessionContext = ModelContext(container)
        sessionContext.autosaveEnabled = false
        context = sessionContext
        settings = RoutinePreferences(ownerID: ownerID).settings
        reload()
    }

    func reload() {
        do {
            let userID = ownerID
            models = try context.fetch(FetchDescriptor<StudySession>(
                predicate: #Predicate { $0.ownerID == userID },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            ))
            guard models.allSatisfy({ SessionState(rawValue: $0.stateRaw) != nil }),
                  models.filter({ $0.stateRaw != SessionState.completed.rawValue }).count <= 1 else {
                throw SessionTrackingError.unreadableStore
            }
            refreshRecords()
            loadError = nil
        } catch {
            current = nil
            history = []
            loadError = SessionTrackingError.unreadableStore.localizedDescription
        }
    }

    func refreshSettings() {
        settings = RoutinePreferences(ownerID: ownerID).settings
    }

    func metrics(at now: Date) -> HomeStudyMetrics {
        SessionAnalytics.dashboard(records: allRecords, now: now, goal: settings.goal(on:))
    }

    func start(subjectID: UUID, zoneID: UUID?, now: Date = .now) throws {
        guard loadError == nil else { throw SessionTrackingError.unreadableStore }
        guard current == nil else { throw SessionTrackingError.alreadyRunning }
        let subject = try selectedSubject(subjectID)
        let zone = try selectedZone(zoneID)
        let previousEnd = history.compactMap(\.endedAt).max() ?? .distantPast
        let date = max(now, previousEnd)
        let session = StudySession(ownerID: ownerID, subject: subject,
                                   zoneID: zone?.id, zoneName: zone?.name, now: date)
        session.intervals = [StudyInterval(subject: subject, now: date)]
        context.insert(session)
        try commit(inserting: session)
    }

    func pause(now: Date = .now) throws {
        guard let session = activeModel else { return }
        guard session.stateRaw == SessionState.running.rawValue else { return }
        closeOpenIntervals(session, at: boundary(for: session, now: now))
        session.stateRaw = SessionState.paused.rawValue
        try commit()
    }

    func resume(now: Date = .now) throws {
        guard let session = activeModel else { throw SessionTrackingError.noSession }
        guard session.stateRaw == SessionState.paused.rawValue else { return }
        let interval = StudyInterval(subject: subjectSnapshot(session), now: boundary(for: session, now: now))
        context.insert(interval)
        session.intervals.append(interval)
        session.stateRaw = SessionState.running.rawValue
        try commit()
    }

    @discardableResult
    func finish(now: Date = .now) throws -> SessionRecord {
        guard let session = activeModel else { throw SessionTrackingError.noSession }
        let date = boundary(for: session, now: now)
        closeOpenIntervals(session, at: date)
        // A subject chosen while paused has no study time until Resume is tapped.
        // Keep the completed session's label on the subject actually studied last.
        let lastStudied = session.intervals.filter {
            ($0.endedAt ?? $0.startedAt) > $0.startedAt
        }.max { ($0.endedAt ?? $0.startedAt) < ($1.endedAt ?? $1.startedAt) }
        if let interval = lastStudied {
            setSubject(SessionSubject(id: interval.subjectID, name: interval.subjectName,
                                      colorID: interval.subjectColorID, iconID: interval.subjectIconID), on: session)
        }
        session.endedAt = date
        session.stateRaw = SessionState.completed.rawValue
        try commit()
        let record = snapshot(session)
        requestSync()
        return record
    }

    func changeSubject(to subjectID: UUID, now: Date = .now) throws {
        guard let session = activeModel else { throw SessionTrackingError.noSession }
        guard session.subjectID != subjectID else { return }
        let subject = try selectedSubject(subjectID)
        let date = boundary(for: session, now: now)
        // Keep the earlier subject's time. Only the new interval uses the new subject.
        if session.stateRaw == SessionState.running.rawValue {
            closeOpenIntervals(session, at: date)
            let interval = StudyInterval(subject: subject, now: date)
            context.insert(interval)
            session.intervals.append(interval)
        }
        setSubject(subject, on: session)
        try commit()
    }

    func requestSync() {
        // A new installation with no local completed sessions must not overwrite cloud totals with zero.
        guard !history.isEmpty, FirebaseApp.app() != nil,
              Auth.auth().currentUser?.uid == ownerID else { return }
        needsSync = true
        guard syncTask == nil else { return }
        syncTask = Task { [weak self] in
            guard let self else { return }
            await self.synchronize()
        }
    }

    private func synchronize() async {
        defer { syncTask = nil }
        let repository = LeaderboardRepository()
        while needsSync {
            needsSync = false
            guard Auth.auth().currentUser?.uid == ownerID else { return }
            let summary = SessionAnalytics.summary(records: history, now: .now, goal: settings.goal(on:))
            do {
                // Serialize replacement writes so an older aggregate cannot finish after a newer one.
                try await repository.publish(summary, userID: ownerID)
                guard Auth.auth().currentUser?.uid == ownerID else { return }
                syncError = nil
            } catch {
                guard Auth.auth().currentUser?.uid == ownerID else { return }
                needsSync = true
                syncError = "Your session is saved. Couldn’t sync study totals."
                return
            }
        }
    }

    private var allRecords: [SessionRecord] { history + (current.map { [$0] } ?? []) }
    private var activeModel: StudySession? {
        guard loadError == nil else { return nil }
        return models.first { $0.stateRaw != SessionState.completed.rawValue }
    }

    private func selectedSubject(_ id: UUID) throws -> SessionSubject {
        let catalog = ModelContext(container)
        let userID = ownerID
        let subjects = try catalog.fetch(FetchDescriptor<StudySubject>(
            predicate: #Predicate { $0.ownerID == userID && $0.id == id && $0.isActive }
        ))
        guard let subject = subjects.first else { throw SessionTrackingError.unavailableSubject }
        return SessionSubject(id: subject.id, name: subject.name, colorID: subject.colorID, iconID: subject.iconID)
    }

    private func selectedZone(_ id: UUID?) throws -> (id: UUID, name: String)? {
        guard let id else { return nil }
        let catalog = ModelContext(container)
        let userID = ownerID
        let zones = try catalog.fetch(FetchDescriptor<StudyZone>(
            predicate: #Predicate { $0.ownerID == userID && $0.id == id && $0.isEnabled }
        ))
        guard let zone = zones.first else { throw SessionTrackingError.unavailableZone }
        return (zone.id, zone.name)
    }

    private func boundary(for session: StudySession, now: Date) -> Date {
        let last = session.intervals.map { $0.endedAt ?? $0.startedAt }.max() ?? session.startedAt
        return max(now, last)
    }

    private func closeOpenIntervals(_ session: StudySession, at date: Date) {
        for interval in session.intervals where interval.endedAt == nil {
            interval.endedAt = max(date, interval.startedAt)
        }
    }

    private func commit(inserting session: StudySession? = nil) throws {
        do {
            try context.save()
            if let session { models.insert(session, at: 0) }
            refreshRecords()
        } catch {
            context.rollback()
            reload()
            throw error
        }
    }

    private func refreshRecords() {
        let records = models.map(snapshot)
        current = records.first { $0.state != .completed }
        history = records.filter { $0.state == .completed }
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
    }

    private func subjectSnapshot(_ session: StudySession) -> SessionSubject {
        SessionSubject(id: session.subjectID, name: session.subjectName,
                       colorID: session.subjectColorID, iconID: session.subjectIconID)
    }

    private func setSubject(_ subject: SessionSubject, on session: StudySession) {
        session.subjectID = subject.id
        session.subjectName = subject.name
        session.subjectColorID = subject.colorID
        session.subjectIconID = subject.iconID
    }

    private func snapshot(_ session: StudySession) -> SessionRecord {
        SessionRecord(
            id: session.id, startedAt: session.startedAt, endedAt: session.endedAt,
            state: SessionState(rawValue: session.stateRaw) ?? .completed,
            subject: subjectSnapshot(session), zoneID: session.zoneID, zoneName: session.zoneName,
            source: session.sourceRaw,
            spans: session.intervals.sorted { $0.startedAt < $1.startedAt }.map {
                SessionSpan(startedAt: $0.startedAt, endedAt: $0.endedAt,
                            subject: SessionSubject(id: $0.subjectID, name: $0.subjectName,
                                                    colorID: $0.subjectColorID, iconID: $0.subjectIconID))
            }
        )
    }
}
