import AppIntents
import Foundation

struct StartStudySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Study Session"
    static let description = IntentDescription("Start studying a subject, or resume your paused session.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Subject")
    var subject: StudySubjectEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Start a study session for \(\.$subject)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let runtime = StudyRuntime.shared
        let initialTracker = try runtime.trackerForShortcut()
        runtime.openHome()

        // Repeating Start must not create a second session.
        if let current = initialTracker.current {
            if current.state == .running {
                return .result(dialog: "Your \(current.subject.name) study session is already running.")
            }
            guard runtime.canResume(current) else { throw StudyShortcutError.outsideStudyZone }
            try initialTracker.resume()
            return .result(dialog: "Resumed your \(current.subject.name) study session.")
        }

        let choices = try await StudySubjectQuery().suggestedEntities()
        guard !choices.isEmpty else { throw StudyShortcutError.noActiveSubjects }
        let chosen: StudySubjectEntity
        if let subject {
            chosen = subject
        } else if choices.count == 1 {
            chosen = choices[0]
        } else {
            chosen = try await $subject.requestDisambiguation(
                among: choices, dialog: "What are you studying?"
            )
        }

        // Asking Siri takes time. Check the account again before changing its data.
        let tracker = try runtime.trackerForShortcut()
        guard tracker.ownerID == initialTracker.ownerID, chosen.ownerID == tracker.ownerID else {
            throw StudyShortcutError.accountChanged
        }
        guard choices.contains(where: { $0.id == chosen.id }) else {
            throw SessionTrackingError.unavailableSubject
        }
        try tracker.start(subjectID: chosen.subjectID, zoneID: nil)
        let name = tracker.current?.subject.name ?? chosen.name
        return .result(dialog: "Started your \(name) study session.")
    }
}

struct StopStudySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Study Session"
    static let description = IntentDescription("Finish and save your current study session, including a paused session.")
    static let openAppWhenRun = true
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let runtime = StudyRuntime.shared
        let tracker = try runtime.trackerForShortcut()
        runtime.openHome()

        guard tracker.current != nil else {
            return .result(dialog: "There’s no study session to stop.")
        }

        // Use the same save, notification cleanup and zone suppression as the Stop button.
        let saved = try tracker.finish()
        return .result(dialog: "Stopped and saved your \(saved.subject.name) study session.")
    }
}
