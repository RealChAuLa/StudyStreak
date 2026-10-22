import Foundation
import Observation

nonisolated struct DailyGoalChange: Codable {
    let effectiveFrom: Date
    let minutes: Int
}

nonisolated struct RoutineSettings: Codable {
    var goals: [DailyGoalChange] = []
    var notificationsEnabled = true
    var streakAlerts = true
    var breakReminders = true
    var reminderMinuteOfDay = 20 * 60
    var breakMinutes = 60

    func goal(on date: Date) -> Int {
        goals.filter { $0.effectiveFrom <= date }
            .max { $0.effectiveFrom < $1.effectiveFrom }?.minutes ?? 120
    }

    var selectedGoal: Int { goals.last?.minutes ?? 120 }

    mutating func setGoal(_ minutes: Int, now: Date = .now, calendar: Calendar = .current) {
        guard (15...240).contains(minutes), minutes.isMultiple(of: 15),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }
        // Keep effective dates so future streak calculations never rewrite earlier goals.
        goals.removeAll { $0.effectiveFrom >= tomorrow }
        goals.append(DailyGoalChange(effectiveFrom: tomorrow, minutes: minutes))
    }

    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        if minutes.isMultiple(of: 60) { return "\(minutes / 60) \(minutes == 60 ? "hour" : "hours")" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

@MainActor @Observable
final class RoutinePreferences {
    var settings: RoutineSettings {
        didSet {
            // The payload contains only dates, integers and booleans.
            if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
        }
    }
    @ObservationIgnored private let key: String
    @ObservationIgnored private let defaults: UserDefaults

    init(ownerID: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = "routinePreferences.\(ownerID)"
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(RoutineSettings.self, from: data) {
            settings = saved
        } else { settings = RoutineSettings() }
    }
}
