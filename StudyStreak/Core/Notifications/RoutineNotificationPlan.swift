import Foundation

nonisolated enum StudyReminderKind: String, Sendable { case streak, breakReminder }

nonisolated struct ScheduledStudyReminder: Identifiable, Equatable, Sendable {
    let id: String
    let ownerID: String
    let kind: StudyReminderKind
    let date: Date
    let title: String
    let body: String
    let sessionID: UUID?
    let focusStartedAt: Date?
}

nonisolated enum RoutineNotificationPlan {
    static let prefix = "StudyStreak.routine."

    static func reminders(ownerID: String, progress: WidgetProgressSnapshot, current: SessionRecord?,
                          settings: RoutineSettings, now: Date, calendar: Calendar = .current) -> [ScheduledStudyReminder] {
        guard !ownerID.isEmpty, settings.notificationsEnabled, progress.state == .available else { return [] }
        var result: [ScheduledStudyReminder] = []
        let projection = WidgetProgressProjection(snapshot: progress, calendar: calendar)
        if settings.streakAlerts {
            let minute = min(1439, max(0, settings.reminderMinuteOfDay))
            let today = calendar.startOfDay(for: now)
            for offset in 0..<14 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      let date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0,
                                               of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                      date > now, calendar.isDate(date, inSameDayAs: day) else { continue }
                // Predictable running time is included; a subsequent pause/stop rebuilds this plan.
                let metrics = projection.metrics(at: date)
                guard metrics.progress < 1 else { continue }
                let parts = calendar.dateComponents([.year, .month, .day], from: date)
                let dayID = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
                result.append(ScheduledStudyReminder(
                    id: "\(prefix)\(ownerID).streak.\(dayID)", ownerID: ownerID, kind: .streak,
                    date: date, title: metrics.streak > 0 ? "Keep your study rhythm" : "Time for a little focus",
                    body: "There’s still time for your daily goal. A little focus adds up.",
                    sessionID: nil, focusStartedAt: nil))
            }
        }
        if settings.breakReminders, let current, let start = focusStart(current, at: now) {
            let minutes = [25, 30, 45, 60, 90, 120].contains(settings.breakMinutes) ? settings.breakMinutes : 60
            let interval = Double(minutes * 60)
            let first = max(1, Int(floor(now.timeIntervalSince(start) / interval)) + 1)
            for offset in 0..<48 {
                let date = start.addingTimeInterval(Double(first + offset) * interval)
                guard date > now, date <= now.addingTimeInterval(86_400) else { continue }
                result.append(ScheduledStudyReminder(
                    id: "\(prefix)\(ownerID).break.\(current.id.uuidString).\(Int(date.timeIntervalSince1970))",
                    ownerID: ownerID, kind: .breakReminder, date: date, title: "A moment to recharge",
                    body: "You’ve been focusing for a while. Take a short pause and come back refreshed.",
                    sessionID: current.id, focusStartedAt: start))
            }
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    // Subject changes create adjoining intervals; only a real pause resets the focus block.
    static func focusStart(_ record: SessionRecord, at now: Date) -> Date? {
        guard record.state == .running else { return nil }
        let ranges = StudyProgress.mergedRanges(record.spans.compactMap { $0.range(at: now) })
        if let last = ranges.last, last.end == now { return last.start }
        return record.spans.filter { $0.endedAt == nil }.map(\.startedAt).min()
    }

    static func shouldPresent(kind: StudyReminderKind, current: SessionRecord?, sessionID: UUID?,
                              focusStartedAt: Date?, settings: RoutineSettings,
                              today: HomeStudyMetrics, now: Date) -> Bool {
        guard settings.notificationsEnabled else { return false }
        switch kind {
        case .streak: return settings.streakAlerts && today.progress < 1
        case .breakReminder:
            guard settings.breakReminders, let current, current.id == sessionID,
                  let start = focusStart(current, at: now), let focusStartedAt else { return false }
            return abs(start.timeIntervalSince(focusStartedAt)) < 0.01
        }
    }
}
