import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationAuthorizationService {
    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var hasLoadedSettings = false

    func refresh() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        hasLoadedSettings = true
    }

    func requestAccess() async throws {
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }
}
