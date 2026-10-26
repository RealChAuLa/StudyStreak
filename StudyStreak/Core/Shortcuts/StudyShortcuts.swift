import AppIntents
import Foundation

nonisolated struct StudyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStudySessionIntent(),
            phrases: [
                "Start my study session in \(.applicationName)",
                "Start a study session in \(.applicationName)",
                "Start studying in \(.applicationName)"
            ],
            shortTitle: "Start studying",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopStudySessionIntent(),
            phrases: [
                "Stop the study session in \(.applicationName)",
                "Stop my study session in \(.applicationName)",
                "Stop studying in \(.applicationName)"
            ],
            shortTitle: "Stop studying",
            systemImageName: "stop.circle"
        )
    }
}

nonisolated enum StudyShortcutError: LocalizedError {
    case signInRequired, studyDataUnavailable, noActiveSubjects, accountChanged
    case accountDeletionInProgress, outsideStudyZone

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Open StudyStreak and sign in before using this shortcut."
        case .studyDataUnavailable: "Open StudyStreak to finish loading your study data, then try again."
        case .noActiveSubjects: "Add or activate a subject in StudyStreak before starting a session."
        case .accountChanged: "Your signed-in account changed. Please run the shortcut again."
        case .accountDeletionInProgress: "Finish deleting your account before using study shortcuts."
        case .outsideStudyZone: "Return to your study zone to resume, or stop this session first."
        }
    }
}
