import Foundation
@preconcurrency import WatchConnectivity

@MainActor
final class PhoneWatchSessionService: NSObject, WCSessionDelegate {
    private weak var runtime: StudyRuntime?
    private var session: WCSession?

    func start(with runtime: StudyRuntime) {
        self.runtime = runtime
        guard session == nil, WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    func refresh() {
        publish(WatchSessionReply(snapshot: snapshot()))
    }

    func clear() {
        publish(WatchSessionReply(snapshot: .unavailable(.signInRequired)))
    }

    private func snapshot() -> WatchSessionSnapshot {
        guard let runtime else { return .unavailable() }
        do {
            let tracker = try runtime.trackerForShortcut()
            let subjects = try runtime.activeSubjectsForShortcut().map {
                WatchSubject(id: $0.id, name: $0.name)
            }
            return WatchSessionSnapshot(accountID: tracker.ownerID, generatedAt: .now,
                access: .ready, subjects: subjects, current: tracker.current.map(watchSession))
        } catch StudyShortcutError.signInRequired {
            return .unavailable(.signInRequired)
        } catch {
            return .unavailable()
        }
    }

    private func watchSession(_ record: SessionRecord) -> WatchStudySession {
        let now = Date.now
        return WatchStudySession(id: record.id,
            subject: WatchSubject(id: record.subject.id, name: record.subject.name),
            elapsedSeconds: record.elapsed(at: now), isRunning: record.state == .running,
            measuredAt: now)
    }

    private func handle(_ request: WatchSessionRequest) -> WatchSessionReply {
        guard let runtime else { return WatchSessionReply(snapshot: .unavailable()) }
        do {
            let tracker = try runtime.trackerForShortcut()
            if request.action == .status {
                let completed = request.accountID == tracker.ownerID
                    ? tracker.history.first { $0.id == request.sessionID }.map(watchSession) : nil
                return WatchSessionReply(snapshot: snapshot(), completed: completed)
            }
            guard request.accountID == tracker.ownerID else {
                return WatchSessionReply(snapshot: snapshot(), message: "Your account changed. Check the session again.")
            }
            // Commands are never queued for later. Reject a stale delivery as well.
            guard abs(request.createdAt.timeIntervalSinceNow) < 10 else {
                return WatchSessionReply(snapshot: snapshot(), message: "That request expired. Check the session again.")
            }
            switch request.action {
            case .status: break
            case .start:
                // A second tap or a simultaneous iPhone start reuses the existing session.
                guard tracker.current == nil else { return WatchSessionReply(snapshot: snapshot()) }
                guard let subjectID = request.subjectID else {
                    return WatchSessionReply(snapshot: snapshot(), message: "Choose a subject first.")
                }
                try tracker.start(subjectID: subjectID, zoneID: nil)
            case .stop:
                // A retry after a lost reply can confirm a session already saved on the phone.
                if let saved = tracker.history.first(where: { $0.id == request.sessionID }) {
                    return WatchSessionReply(snapshot: snapshot(), completed: watchSession(saved))
                }
                guard let current = tracker.current, current.id == request.sessionID else {
                    return WatchSessionReply(snapshot: snapshot(), message: "The session changed. Check its current status.")
                }
                let saved = try tracker.finish()
                return WatchSessionReply(snapshot: snapshot(), completed: watchSession(saved))
            }
            return WatchSessionReply(snapshot: snapshot())
        } catch {
            return WatchSessionReply(snapshot: snapshot(), message: error is StudyShortcutError
                ? "Open StudyStreak on your iPhone and check your account."
                : SessionTrackingError.message(for: error))
        }
    }

    private func publish(_ reply: WatchSessionReply) {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(reply) else { return }
        let message: [String: Any] = [WatchSessionMessage.dataKey: data]
        // Context keeps only the newest state; live messages update an open watch app.
        try? session.updateApplicationContext(message)
        if session.isReachable { session.sendMessage(message, replyHandler: nil, errorHandler: { _ in }) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard let data = message[WatchSessionMessage.dataKey] as? Data,
              let request = try? JSONDecoder().decode(WatchSessionRequest.self, from: data) else {
            replyHandler([:])
            return
        }
        Task { @MainActor [weak self] in
            let reply = self?.handle(request) ?? WatchSessionReply(snapshot: .unavailable())
            let data = (try? JSONEncoder().encode(reply)) ?? Data()
            replyHandler([WatchSessionMessage.dataKey: data])
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

