import Combine
import Foundation
import WatchKit

@MainActor
final class WatchSessionViewModel: ObservableObject {
    enum Screen {
        case loading, ready, subjects, active, confirmStop, saved
        case unavailable, stopNotConfirmed, noSubjects, phoneSetup
    }

    @Published private(set) var screen: Screen = .loading
    @Published private(set) var snapshot = WatchSessionSnapshot.unavailable()
    @Published private(set) var selectedSubjectID: UUID?
    @Published private(set) var pendingAction: WatchSessionAction?
    @Published private(set) var sessionToStop: WatchStudySession?
    @Published private(set) var savedSession: WatchStudySession?
    @Published private(set) var message = ""

    private let connection: WatchConnectionService
    private let isPreview: Bool
    private var hasLiveState = false
    private var pendingRequest: WatchSessionRequest?
    private var unconfirmedStopID: UUID?
    private var timeoutTask: Task<Void, Never>?

    var selectedSubject: WatchSubject? {
        snapshot.subjects.first { $0.id == selectedSubjectID } ?? snapshot.subjects.first
    }
    var isConnected: Bool { isPreview || connection.isReachable }

    init(preview: WatchSessionSnapshot? = nil) {
        connection = WatchConnectionService()
        isPreview = preview != nil
        connection.onReady = { [weak self] in self?.refresh() }
        connection.onUpdate = { [weak self] reply in self?.receive(reply) }
        connection.onDisconnect = { [weak self] in
            guard let self, self.pendingAction == nil else { return }
            self.screen = self.unconfirmedStopID == nil ? .unavailable : .stopNotConfirmed
        }
        if let preview {
            snapshot = preview
            hasLiveState = true
            showCurrentState()
        }
    }

    func connect() {
        guard !isPreview else { return }
        connection.activate()
    }

    func refresh() {
        guard !isPreview, pendingAction == nil else { return }
        send(WatchSessionRequest(action: .status, accountID: snapshot.accountID,
                                 sessionID: unconfirmedStopID))
    }

    func chooseSubject() { screen = .subjects }

    func select(_ subject: WatchSubject) {
        selectedSubjectID = subject.id
        screen = .ready
    }

    func cancelSubjectSelection() { showCurrentState() }

    func start() {
        guard pendingAction == nil, let subject = selectedSubject else { return }
        send(WatchSessionRequest(action: .start, accountID: snapshot.accountID, subjectID: subject.id))
    }

    func confirmStop() {
        guard let current = snapshot.current, pendingAction == nil else { return }
        sessionToStop = current
        screen = .confirmStop
    }

    func keepStudying() { showCurrentState() }

    func stop() {
        guard pendingAction == nil, let current = snapshot.current else { return }
        unconfirmedStopID = current.id
        send(WatchSessionRequest(action: .stop, accountID: snapshot.accountID, sessionID: current.id))
    }

    func done() {
        savedSession = nil
        showCurrentState()
        refresh()
    }

    private func send(_ request: WatchSessionRequest) {
        pendingRequest = request
        pendingAction = request.action
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(12)) }
            catch { return }
            guard let self, self.pendingRequest?.id == request.id else { return }
            self.failed(request)
        }
        connection.send(request) { [weak self] result in
            guard let self else { return }
            guard self.pendingRequest?.id == request.id else {
                // A late confirmation can still resolve an uncertain stop.
                if case .success(let reply) = result { self.receive(reply) }
                return
            }
            switch result {
            case .success(let reply):
                self.timeoutTask?.cancel()
                self.pendingRequest = nil
                self.pendingAction = nil
                self.receive(reply, isLiveReply: true)
                if request.action != .status, request.accountID != self.snapshot.accountID { return }
                if let message = reply.message {
                    self.message = message
                    self.screen = request.action == .stop ? .stopNotConfirmed : .phoneSetup
                } else if request.action == .start, self.snapshot.current != nil {
                    WKInterfaceDevice.current().play(.start)
                }
            case .failure:
                self.failed(request)
            }
        }
    }

    private func failed(_ request: WatchSessionRequest) {
        timeoutTask?.cancel()
        pendingRequest = nil
        pendingAction = nil
        screen = unconfirmedStopID == nil ? .unavailable : .stopNotConfirmed
    }

    private func receive(_ reply: WatchSessionReply, isLiveReply: Bool = false) {
        // Don't restore an old user's cached context when the app first opens.
        guard isLiveReply || hasLiveState else { return }
        let isNewer = !hasLiveState || reply.snapshot.generatedAt >= snapshot.generatedAt
        guard isNewer || reply.snapshot.accountID == snapshot.accountID else {
            if pendingAction == nil { showCurrentState() }
            return
        }
        let changedAccount = isNewer && hasLiveState && snapshot.accountID != reply.snapshot.accountID
        let wasChoosing = screen == .subjects
        let wasConfirming = screen == .confirmStop && snapshot.current?.id == reply.snapshot.current?.id
        if isNewer { snapshot = reply.snapshot }
        hasLiveState = true
        if changedAccount {
            selectedSubjectID = nil
            savedSession = nil
            sessionToStop = nil
            unconfirmedStopID = nil
            pendingRequest = nil
            pendingAction = nil
            timeoutTask?.cancel()
        }
        if let saved = reply.completed, saved.id == unconfirmedStopID {
            unconfirmedStopID = nil
            if snapshot.current == nil {
                savedSession = saved
                screen = .saved
                WKInterfaceDevice.current().play(.success)
                return
            }
        }
        guard pendingAction == nil else { return }
        if isLiveReply { unconfirmedStopID = nil }
        guard connection.isReachable || isPreview else {
            screen = unconfirmedStopID == nil ? .unavailable : .stopNotConfirmed
            return
        }
        showCurrentState()
        if wasChoosing, screen == .ready { screen = .subjects }
        if wasConfirming, snapshot.current != nil, !changedAccount { screen = .confirmStop }
    }

    private func showCurrentState() {
        switch snapshot.access {
        case .signInRequired:
            message = "Sign in to StudyStreak on your iPhone, then refresh."
            screen = .phoneSetup
        case .unavailable:
            message = "Open StudyStreak on your iPhone and finish setting up your account."
            screen = .phoneSetup
        case .ready:
            if snapshot.current != nil { screen = .active }
            else if savedSession != nil { screen = .saved }
            else { screen = snapshot.subjects.isEmpty ? .noSubjects : .ready }
        }
    }
}

