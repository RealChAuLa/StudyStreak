import UIKit
import UserNotifications

@MainActor
final class StudyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        StudyRuntime.shared.notifications.registerActions()
        if launchOptions?[.location] != nil { StudyRuntime.shared.recoverLocationLaunch() }
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let content = notification.request.content
        let category = content.categoryIdentifier
        let ownerID = content.userInfo["ownerID"] as? String
        let sessionID = (content.userInfo["sessionID"] as? String).flatMap(UUID.init(uuidString:))
        let focus = (content.userInfo["focusStartedAt"] as? Double).map(Date.init(timeIntervalSince1970:))
        let kind = (content.userInfo["reminderKind"] as? String).flatMap(StudyReminderKind.init(rawValue:))
        return await MainActor.run {
            let runtime = StudyRuntime.shared
            if category == AutomaticSessionNotifications.category {
                guard let ownerID, runtime.shouldShowAutomaticNotice(ownerID: ownerID, sessionID: sessionID) else { return [] }
            } else if category == RoutineStudyNotifications.streakCategory || category == RoutineStudyNotifications.breakCategory {
                guard let ownerID, let kind,
                      runtime.shouldShowReminder(kind: kind, ownerID: ownerID, sessionID: sessionID, focusStartedAt: focus) else { return [] }
            }
            return [.banner, .list, .sound]
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let category = content.categoryIdentifier
        guard let ownerID = content.userInfo["ownerID"] as? String else { return }
        let sessionID = (content.userInfo["sessionID"] as? String).flatMap(UUID.init(uuidString:))
        let action = response.actionIdentifier
        let opensHome = action == UNNotificationDefaultActionIdentifier
        let subjectName = (response as? UNTextInputNotificationResponse)?.userText
        let kind = (content.userInfo["reminderKind"] as? String).flatMap(StudyReminderKind.init(rawValue:))
        let focus = (content.userInfo["focusStartedAt"] as? Double).map(Date.init(timeIntervalSince1970:))
        await MainActor.run {
            let runtime = StudyRuntime.shared
            if category == AutomaticSessionNotifications.category, let sessionID {
                if opensHome, runtime.tracker?.ownerID == ownerID { runtime.openHome() }
                runtime.handleNotificationAction(action, ownerID: ownerID, sessionID: sessionID, subjectName: subjectName)
            } else if category == RoutineStudyNotifications.streakCategory || category == RoutineStudyNotifications.breakCategory,
                      let kind {
                runtime.handleReminderAction(action, kind: kind, ownerID: ownerID, sessionID: sessionID,
                                             focusStartedAt: focus, opensHome: opensHome)
            }
        }
    }
}
