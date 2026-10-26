import Foundation
import Observation
import OSLog
@preconcurrency import UserNotifications

@MainActor @Observable
final class RoutineStudyNotifications {
    nonisolated static let streakCategory = "STUDYSTREAK_STREAK_REMINDER"
    nonisolated static let breakCategory = "STUDYSTREAK_BREAK_REMINDER"
    nonisolated static let pauseAction = "STUDYSTREAK_TAKE_A_BREAK"
    private(set) var errorMessage: String?
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private var scheduleVersion = 0
    @ObservationIgnored private var pendingPlan: [ScheduledStudyReminder]?
    @ObservationIgnored private var lastScheduledPlan: [ScheduledStudyReminder]?
    @ObservationIgnored private var scheduleTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "realchaula.StudyStreak", category: "StudyReminders")

    static var categories: Set<UNNotificationCategory> {
        let pause = UNNotificationAction(identifier: pauseAction, title: "Take a break", options: [],
                                          icon: UNNotificationActionIcon(systemImageName: "pause"))
        return [
            UNNotificationCategory(identifier: streakCategory, actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: breakCategory, actions: [pause], intentIdentifiers: [], options: [])
        ]
    }

    // One task updates reminders in order. A newer plan replaces any unfinished plan.
    func update(_ reminders: [ScheduledStudyReminder], force: Bool = false) {
        if !force, scheduleTask == nil, reminders == lastScheduledPlan { return }
        scheduleVersion += 1
        pendingPlan = reminders
        guard scheduleTask == nil else { return }
        scheduleTask = Task { [weak self] in
            guard let self else { return }
            await self.applyPendingPlans()
        }
    }

    func clear() { update([], force: true) }

    func cancelAndWait() async {
        clear()
        let pending = scheduleTask
        await pending?.value
    }

    private func applyPendingPlans() async {
        defer { scheduleTask = nil }
        while let plan = pendingPlan {
            pendingPlan = nil
            let expectedVersion = scheduleVersion
            let pending = await center.pendingNotificationRequests()
            let owned = pending.filter { $0.identifier.hasPrefix(RoutineNotificationPlan.prefix) }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: owned)
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers: delivered.filter {
                $0.request.identifier.hasPrefix(RoutineNotificationPlan.prefix)
            }.map(\.request.identifier))
            guard scheduleVersion == expectedVersion else { continue }

            let authorization = await center.notificationSettings().authorizationStatus
            let allowed = authorization == .authorized || authorization == .provisional || authorization == .ephemeral
            guard scheduleVersion == expectedVersion else { continue }
            guard allowed, !plan.isEmpty else {
                lastScheduledPlan = plan.isEmpty ? [] : nil
                errorMessage = nil
                continue
            }
            // Leave room for any other pending app notifications; never exceed iOS's request limit.
            let otherCount = pending.count - owned.count
            let capacity = max(0, 64 - otherCount)
            var failed = false
            for reminder in plan.prefix(capacity) {
                guard scheduleVersion == expectedVersion else { break }
                let interval = reminder.date.timeIntervalSinceNow
                guard interval > 0 else { continue }
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.body
                content.sound = .default
                content.categoryIdentifier = reminder.kind == .streak ? Self.streakCategory : Self.breakCategory
                var info: [String: Any] = ["ownerID": reminder.ownerID, "reminderKind": reminder.kind.rawValue]
                if let id = reminder.sessionID { info["sessionID"] = id.uuidString }
                if let start = reminder.focusStartedAt { info["focusStartedAt"] = start.timeIntervalSince1970 }
                content.userInfo = info
                let trigger: UNNotificationTrigger
                if reminder.kind == .streak {
                    var parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                                from: reminder.date)
                    parts.timeZone = .current
                    trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                } else {
                    trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
                }
                do {
                    try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
                } catch {
                    failed = true
                    logger.error("Could not schedule reminder: \(error.localizedDescription, privacy: .public)")
                }
            }
            guard scheduleVersion == expectedVersion else { continue }
            lastScheduledPlan = failed ? nil : plan
            errorMessage = failed ? "Couldn’t update your reminders. Please try again." : nil
        }
    }
}
