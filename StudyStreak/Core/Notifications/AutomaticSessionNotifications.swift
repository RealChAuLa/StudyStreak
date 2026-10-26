import Foundation
import UserNotifications

@MainActor
final class AutomaticSessionNotifications {
    nonisolated static let category = "STUDYSTREAK_AUTOMATIC_SESSION"
    nonisolated static let confirmAction = "STUDYSTREAK_CONFIRM_SUBJECT"
    nonisolated static let changeAction = "STUDYSTREAK_CHANGE_SUBJECT"
    private let center = UNUserNotificationCenter.current()

    func registerActions() {
        let confirm = UNNotificationAction(identifier: Self.confirmAction, title: "That’s right",
                                           options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark"))
        // Native notification text input permits changing a saved subject without opening the app.
        let change = UNTextInputNotificationAction(
            identifier: Self.changeAction, title: "Change subject", options: [.authenticationRequired],
            icon: UNNotificationActionIcon(systemImageName: "book"),
            textInputButtonTitle: "Save", textInputPlaceholder: "Name of an active subject")
        let category = UNNotificationCategory(identifier: Self.category, actions: [confirm, change],
                                               intentIdentifiers: [], options: [])
        center.setNotificationCategories(Set([category]).union(RoutineStudyNotifications.categories))
    }

    func postStarted(_ session: SessionRecord, ownerID: String) {
        guard RoutinePreferences(ownerID: ownerID).settings.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your study session has started"
        content.body = "Studying \(session.subject.name) at \(session.zoneName ?? "your study zone").\nIs that what you’re working on?"
        content.categoryIdentifier = Self.category
        content.userInfo = ["ownerID": ownerID, "sessionID": session.id.uuidString, "createdAt": Date.now.timeIntervalSince1970]
        content.sound = .default
        center.add(UNNotificationRequest(identifier: identifier(session.id), content: content, trigger: nil)) { _ in }
    }

    func postSubjectNotFound(_ session: SessionRecord, ownerID: String) {
        guard RoutinePreferences(ownerID: ownerID).settings.notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Choose a saved subject"
        content.body = "Use the name of an active subject. Your session is still tagged \(session.subject.name)."
        content.categoryIdentifier = Self.category
        content.userInfo = ["ownerID": ownerID, "sessionID": session.id.uuidString, "createdAt": Date.now.timeIntervalSince1970]
        center.add(UNNotificationRequest(identifier: identifier(session.id), content: content, trigger: nil)) { _ in }
    }

    func cancel(_ sessionID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(sessionID)])
        center.removeDeliveredNotifications(withIdentifiers: [identifier(sessionID)])
    }

    func cancelAll(ownerID: String?) {
        let cutoff = Date.now.timeIntervalSince1970
        center.getPendingNotificationRequests { [center] requests in
            let ids = requests.filter {
                $0.identifier.hasPrefix("StudyStreak.automatic.")
                    && (ownerID == nil || $0.content.userInfo["ownerID"] as? String == ownerID)
                    && ($0.content.userInfo["createdAt"] as? Double ?? 0) <= cutoff
            }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
        center.getDeliveredNotifications { [center] notifications in
            let ids = notifications.filter {
                let content = $0.request.content
                return $0.request.identifier.hasPrefix("StudyStreak.automatic.")
                    && (ownerID == nil || content.userInfo["ownerID"] as? String == ownerID)
                    && (content.userInfo["createdAt"] as? Double ?? 0) <= cutoff
            }.map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func cancelAllAndWait(ownerID: String) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter {
            $0.identifier.hasPrefix("StudyStreak.automatic.") && $0.content.userInfo["ownerID"] as? String == ownerID
        }.map(\.identifier))
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter {
            $0.request.identifier.hasPrefix("StudyStreak.automatic.")
                && $0.request.content.userInfo["ownerID"] as? String == ownerID
        }.map(\.request.identifier))
    }

    private func identifier(_ sessionID: UUID) -> String { "StudyStreak.automatic.\(sessionID.uuidString)" }
}
