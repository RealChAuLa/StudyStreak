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
        notifications.registerActions()
        guard FirebaseApp.app() != nil else { zones.stop(); widgets.clear(); return }
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
        guard let userID else {
            let oldOwner = tracker?.ownerID
            try? tracker?.pause(reason: .signedOut)
            zones.stop()
            notifications.cancelAll(ownerID: oldOwner)
            definitions = []
            tracker = nil
            widgets.clear()
            return
        }
        if tracker?.ownerID != userID {
            if let old = tracker {
                try? old.pause(reason: .signedOut)
                zones.stop()
                notifications.cancelAll(ownerID: old.ownerID)
            }
            widgets.clear()
            definitions = []
            automationError = nil
            tracker = StudySessionTracker(container: container, ownerID: userID)
        }
        guard let tracker else { return }
        let ownerID = tracker.ownerID
        tracker.onProgressChanged = { [weak self] in self?.publishWidgetProgress() }
        publishWidgetProgress()
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
        automationError = nil
        tracker?.refreshSettings()
        tracker?.requestSync()
        refreshCatalog(requestStates: true)
    }

    func openHome() { homeNavigationRequest = UUID() }

    func publishWidgetProgress(forceReload: Bool = false) {
        guard let tracker, FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == tracker.ownerID else { return }
        widgets.publish(tracker, forceReload: forceReload)
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
        guard FirebaseApp.app() != nil, Auth.auth().currentUser?.uid == ownerID else { return }
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
