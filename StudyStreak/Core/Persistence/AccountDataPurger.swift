import Foundation
import SwiftData

@MainActor
enum AccountDataPurger {
    static func erase(userID: String, in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let sessions = try context.fetch(FetchDescriptor<StudySession>(
                predicate: #Predicate { $0.ownerID == userID }))
            let zones = try context.fetch(FetchDescriptor<StudyZone>(
                predicate: #Predicate { $0.ownerID == userID }))
            let subjects = try context.fetch(FetchDescriptor<StudySubject>(
                predicate: #Predicate { $0.ownerID == userID }))
            for session in sessions { context.delete(session) } // Cascades to its study intervals.
            for zone in zones { context.delete(zone) }
            for subject in subjects { context.delete(subject) }
            try context.save()
        } catch { context.rollback(); throw error }

        for key in ["routinePreferences.\(userID)", "automaticZones.enabled.\(userID)",
                    "automaticZones.suppressed.\(userID)", "leaderboardHistoryReplacement.\(userID)"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
