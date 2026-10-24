import UIKit
import UserNotifications

@MainActor
final class StudyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        StudyRuntime.shared.notifications.registerActions()
        // The runtime is configured during App.init, before the first SwiftUI screen.
        if launchOptions?[.location] != nil { StudyRuntime.shared.recoverLocationLaunch() }
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let isAutomatic = notification.request.content.categoryIdentifier == AutomaticSessionNotifications.category
        return await MainActor.run {
            if isAutomatic && StudyRuntime.shared.homeCanShowConfirmation { return [] }
            return [.banner, .list]
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard content.categoryIdentifier == AutomaticSessionNotifications.category,
              let ownerID = content.userInfo["ownerID"] as? String,
              let idString = content.userInfo["sessionID"] as? String,
              let sessionID = UUID(uuidString: idString) else { return }
        let action = response.actionIdentifier
        let subjectName = (response as? UNTextInputNotificationResponse)?.userText
        await MainActor.run {
            StudyRuntime.shared.handleNotificationAction(action, ownerID: ownerID,
                                                        sessionID: sessionID, subjectName: subjectName)
        }
    }
}
