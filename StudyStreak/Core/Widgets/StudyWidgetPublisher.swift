import Foundation
import OSLog
import WidgetKit

@MainActor
final class StudyWidgetPublisher {
    private var lastOwnerID: String?
    private var lastSnapshot: WidgetProgressSnapshot?
    private let logger = Logger(subsystem: "realchaula.StudyStreak", category: "WidgetProgress")

    func publish(_ tracker: StudySessionTracker, now: Date = .now, forceReload: Bool = false) {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        let snapshot = tracker.widgetSnapshot(at: now)
        if !forceReload, lastOwnerID == tracker.ownerID,
           let lastSnapshot, snapshot.hasSameProgress(as: lastSnapshot) { return }
        do {
            try WidgetProgressStore.write(snapshot)
            lastOwnerID = tracker.ownerID
            lastSnapshot = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: StudyWidgetConfiguration.kind)
        } catch {
            logger.error("Could not share widget progress: \(error.localizedDescription, privacy: .public)")
        }
    }

    func clear() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        do {
            try WidgetProgressStore.write(.empty(.signedOut))
            lastOwnerID = nil
            lastSnapshot = nil
            WidgetCenter.shared.reloadTimelines(ofKind: StudyWidgetConfiguration.kind)
        } catch {
            logger.error("Could not clear widget progress: \(error.localizedDescription, privacy: .public)")
        }
    }
}
