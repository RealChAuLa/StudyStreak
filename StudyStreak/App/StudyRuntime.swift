import FirebaseAuth
import FirebaseCore
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StudyRuntime {
    static let shared = StudyRuntime()
    let zones = StudyZoneMonitoringService()
    let notifications = AutomaticSessionNotifications()
    let reminders = RoutineStudyNotifications()
    let widgets = StudyWidgetPublisher()
    var homeNavigationRequest = UUID()
    private(set) var tracker: StudySessionTracker?
    private(set) var automationError: String?
    var homeCanShowConfirmation = false
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private weak var account: AppSession?
    @ObservationIgnored private var definitions: [MonitoredStudyZone] = []

    private init() {
        zones.onObservation = { [weak self] id, state in self?.observe(id, state: state) }
        zones.onUnavailable = { [weak self] reason in self?.pauseForUnavailableMonitoring(reason) }
    }

    func configure(container: ModelContainer, account: AppSession) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        self.container = container
        self.account = account
        account.prepareForAccountDeletion = { [weak self] userID in
            guard let self else { throw AccountError.notConfigured }
            try await self.prepareForDeletion(userID: userID)
        }
        notifications.registerActions()
        guard FirebaseApp.app() != nil else { zones.stop(); widgets.clear(); reminders.clear(); return }
        account.onStudyUserChanged = { [weak self] userID in self?.activate(userID) }
        if FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid {
            activate(uid)
        }
        // A nil currentUser at launch may still be restoring. Wait for the Auth listener
        // before removing previously registered regions.
    }

    func recoverLocationLaunch() {
        guard FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid else { return }
        activate(uid)
    }

    func activate(_ userID: String?) {
        guard let container else { return }
        if let userID, AccountDeletionState.isPending(userID) {
            zones.stop()
            notifications.cancelAll(ownerID: nil)
            reminders.clear()
            widgets.clear()
            definitions = []
            tracker = nil
            return
        }
        guard let userID else {
            let oldOwner = tracker?.ownerID
            try? tracker?.pause(reason: .signedOut)
            zones.stop()
            notifications.cancelAll(ownerID: oldOwner)
            definitions = []
            tracker = nil
            widgets.clear()
            reminders.clear()
            return
        }
        if tracker?.ownerID != userID {
            if let old = tracker {
                try? old.pause(reason: .signedOut)
                zones.stop()
                notifications.cancelAll(ownerID: old.ownerID)
            }
            widgets.clear()
            reminders.clear()
            definitions = []
            automationError = nil
            tracker = StudySessionTracker(container: container, ownerID: userID)
        }
        guard let tracker else { return }
        let ownerID = tracker.ownerID
        tracker.onProgressChanged = { [weak self] in self?.studyProgressDidChange() }
        studyProgressDidChange()
        tracker.onUserFinished = { [weak self] record in
            guard let self, self.tracker?.ownerID == ownerID else { return }
            // Unknown overlapping regions may report Inside after Stop; hold those
            // too until an Outside observation confirms the user has left.
            var suppressed = Set(self.zones.monitoredZoneIDs.filter { self.zones.presence[$0] != .outside })
            if record.isAutomatic, record.pauseReason != .zoneExit, let zoneID = record.zoneID,
               self.zones.presence[zoneID] != .outside { suppressed.insert(zoneID) }
            self.zones.suppressUntilExit(suppressed)
            self.notifications.cancel(record.id)
        }
        account?.prepareForSignOut = { [weak self] in
            guard let self else { return }
            try self.tracker?.pause(reason: .signedOut)
            self.zones.stop()
            self.notifications.cancelAll(ownerID: self.tracker?.ownerID)
            self.reminders.clear()
        }
        refreshCatalog(requestStates: true)
    }

    func refreshCatalog(requestStates: Bool = false) {
        guard let container, let tracker else { return }
        do {
            let context = ModelContext(container)
            let ownerID = tracker.ownerID
            let saved = try context.fetch(FetchDescriptor<StudyZone>(
                predicate: #Predicate { $0.ownerID == ownerID && $0.isEnabled }))
            let updated = saved.compactMap { zone -> MonitoredStudyZone? in
                guard let subject = zone.defaultSubject, subject.ownerID == ownerID, subject.isActive,
                      zone.latitude.isFinite, zone.longitude.isFinite,
                      (-90...90).contains(zone.latitude), (-180...180).contains(zone.longitude),
                      zone.radiusMeters.isFinite, (100...500).contains(zone.radiusMeters) else { return nil }
                return MonitoredStudyZone(id: zone.id, ownerID: ownerID, name: zone.name,
                    latitude: zone.latitude, longitude: zone.longitude, radius: zone.radiusMeters,
                    subjectID: subject.id, createdAt: zone.createdAt)
            }.sorted { $0.id.uuidString < $1.id.uuidString }
            guard updated != definitions || requestStates else { return }
            definitions = updated
            zones.configure(ownerID: ownerID, zones: updated, requestStates: requestStates)
            if let current = tracker.current, current.isAutomatic, current.state == .running,
               let zoneID = current.zoneID, !zones.monitoredZoneIDs.contains(zoneID) {
                try tracker.pause(reason: .zoneUnavailable)
                notifications.cancel(current.id)
            }
        } catch { automationError = "Couldn’t update automatic study zones. Please try again." }
    }

    func refresh() {
        if let tracker, AccountDeletionState.isPending(tracker.ownerID) { reminders.clear(); return }
        automationError = nil
        tracker?.refreshSettings()
        tracker?.requestSync()
        refreshCatalog(requestStates: true)
        refreshNotificationSchedule(force: true)
    }

    func openHome() { homeNavigationRequest = UUID() }

    func publishWidgetProgress(forceReload: Bool = false) {
        guard let tracker, !AccountDeletionState.isPending(tracker.ownerID),
              FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == tracker.ownerID else { return }
        widgets.publish(tracker, forceReload: forceReload)
    }

    private func studyProgressDidChange() {
        publishWidgetProgress()
        refreshNotificationSchedule()
        if let tracker, !tracker.settings.notificationsEnabled {
            notifications.cancelAll(ownerID: tracker.ownerID)
        }
    }

    func refreshNotificationSchedule(force: Bool = false) {
        guard let tracker, !tracker.isSuspendedForDeletion, !AccountDeletionState.isPending(tracker.ownerID),
              FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == tracker.ownerID else {
            reminders.clear()
            return
        }
        let now = Date.now
        reminders.update(RoutineNotificationPlan.reminders(
            ownerID: tracker.ownerID, progress: tracker.widgetSnapshot(at: now), current: tracker.current,
            settings: tracker.settings, now: now), force: force)
    }

    func shouldShowReminder(kind: StudyReminderKind, ownerID: String, sessionID: UUID?, focusStartedAt: Date?) -> Bool {
        guard let tracker, tracker.ownerID == ownerID, !AccountDeletionState.isPending(ownerID),
              FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == ownerID else { return false }
        let now = Date.now
        return RoutineNotificationPlan.shouldPresent(kind: kind, current: tracker.current, sessionID: sessionID,
            focusStartedAt: focusStartedAt, settings: tracker.settings, today: tracker.metrics(at: now), now: now)
    }

    func shouldShowAutomaticNotice(ownerID: String, sessionID: UUID?) -> Bool {
        guard let tracker, tracker.ownerID == ownerID, !AccountDeletionState.isPending(ownerID),
              FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == ownerID,
              tracker.settings.notificationsEnabled, let current = tracker.current,
              current.id == sessionID, current.state == .running, current.needsSubjectConfirmation else { return false }
        return !homeCanShowConfirmation
    }

    func handleReminderAction(_ action: String, kind: StudyReminderKind, ownerID: String,
                              sessionID: UUID?, focusStartedAt: Date?, opensHome: Bool) {
        guard let tracker, tracker.ownerID == ownerID, !AccountDeletionState.isPending(ownerID),
              FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == ownerID else { return }
        if opensHome { openHome(); return }
        guard action == RoutineStudyNotifications.pauseAction, kind == .breakReminder,
              shouldShowReminder(kind: kind, ownerID: ownerID, sessionID: sessionID, focusStartedAt: focusStartedAt) else { return }
        do { try tracker.pause(reason: .user) }
        catch { automationError = SessionTrackingError.message(for: error) }
    }

    private func prepareForDeletion(userID: String) async throws {
        guard FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == userID,
              tracker == nil || tracker?.ownerID == userID else { throw AccountDeletionError.accountChanged }
        definitions = []
        zones.stop()
        notifications.cancelAll(ownerID: nil)
        reminders.clear()
        widgets.clear()
        if let tracker { try await tracker.suspendForAccountDeletion() }
        await reminders.cancelAndWait()
        await notifications.cancelAllAndWait(ownerID: userID)
        tracker = nil
    }

    func canResume(_ session: SessionRecord) -> Bool {
        !session.isAutomatic || (zones.isReady && session.zoneID.map { zones.presence[$0] == .inside } == true)
    }

    func confirm(_ sessionID: UUID) {
        do {
            try tracker?.confirmSubject(sessionID: sessionID)
            notifications.cancel(sessionID)
        } catch { automationError = SessionTrackingError.message(for: error) }
    }

    func handleNotificationAction(_ action: String, ownerID: String, sessionID: UUID, subjectName: String?) {
        guard !AccountDeletionState.isPending(ownerID), FirebaseApp.app() != nil,
              Auth.auth().currentUser?.uid == ownerID else { return }
        recoverLocationLaunch()
        guard let tracker, tracker.ownerID == ownerID, let current = tracker.current,
              current.id == sessionID, current.isAutomatic else { return }
        if action == AutomaticSessionNotifications.confirmAction {
            confirm(sessionID)
        } else if action == AutomaticSessionNotifications.changeAction, let subjectName, let container {
            do {
                let context = ModelContext(container)
                let subjects = try context.fetch(FetchDescriptor<StudySubject>(
                    predicate: #Predicate { $0.ownerID == ownerID && $0.isActive }))
                guard let subject = subjects.first(where: {
                    SubjectStore.normalizedName($0.name) == SubjectStore.normalizedName(subjectName)
                }) else {
                    notifications.postSubjectNotFound(current, ownerID: ownerID)
                    return
                }
                try tracker.changeSubject(to: subject.id)
                try tracker.confirmSubject(sessionID: sessionID)
                notifications.cancel(sessionID)
            } catch { automationError = SessionTrackingError.message(for: error) }
        }
    }

    private func observe(_ zoneID: UUID, state: ZonePresence) {
        guard let tracker, FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == tracker.ownerID,
              let zone = definitions.first(where: { $0.id == zoneID }) else { return }
        let action = ZoneAutomationPolicy.action(zoneID: zoneID, presence: state, current: tracker.current,
                                                  inside: zones.insideZoneIDs, suppressed: zones.suppressedZoneIDs)
        do {
            switch action {
            case .none: break
            case .start:
                try tracker.start(subjectID: zone.subjectID, zoneID: zone.id, source: .automatic)
                if let current = tracker.current { notifications.postStarted(current, ownerID: tracker.ownerID) }
            case .resume:
                do { try tracker.resumeAutomatically() }
                catch SessionTrackingError.unavailableSubject {
                    try tracker.finish(automatically: true)
                    try tracker.start(subjectID: zone.subjectID, zoneID: zone.id, source: .automatic)
                    if let current = tracker.current { notifications.postStarted(current, ownerID: tracker.ownerID) }
                }
            case .pause:
                let oldID = tracker.current?.id
                try tracker.pause(reason: .zoneExit)
                if let oldID { notifications.cancel(oldID) }
                // Overlapping zones keep the current one until its exit. Then choose
                // a remaining inside zone deterministically.
                if let next = definitions.filter({
                    zones.insideZoneIDs.contains($0.id) && !zones.suppressedZoneIDs.contains($0.id)
                }).sorted(by: { $0.radius == $1.radius ? $0.id.uuidString < $1.id.uuidString : $0.radius < $1.radius }).first {
                    observe(next.id, state: .inside)
                }
            case .switchZone:
                try tracker.finish(automatically: true)
                try tracker.start(subjectID: zone.subjectID, zoneID: zone.id, source: .automatic)
                if let current = tracker.current { notifications.postStarted(current, ownerID: tracker.ownerID) }
            }
            automationError = nil
        } catch { automationError = SessionTrackingError.message(for: error) }
    }

    private func pauseForUnavailableMonitoring(_ reason: SessionPauseReason) {
        guard let tracker, let current = tracker.current, current.isAutomatic, current.state == .running else { return }
        if reason == .zoneUnavailable, let zoneID = current.zoneID, zones.monitoringErrors[zoneID] == nil { return }
        do {
            try tracker.pause(reason: reason)
            notifications.cancel(current.id)
        } catch { automationError = SessionTrackingError.message(for: error) }
    }
}
