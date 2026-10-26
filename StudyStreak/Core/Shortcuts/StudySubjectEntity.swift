import AppIntents
import Foundation

// A lightweight subject value Siri can display. The owner is part of its stable ID.
nonisolated struct StudySubjectEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Study subject")
    static let defaultQuery = StudySubjectQuery()

    let subjectID: UUID
    let ownerID: String
    let name: String

    var id: String { "\(ownerID):\(subjectID.uuidString)" }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

nonisolated struct StudySubjectQuery: EntityStringQuery {
    @MainActor
    func suggestedEntities() async throws -> [StudySubjectEntity] {
        let runtime = StudyRuntime.shared
        let tracker = try runtime.trackerForShortcut()
        return try runtime.activeSubjectsForShortcut().map {
            StudySubjectEntity(subjectID: $0.id, ownerID: tracker.ownerID, name: $0.name)
        }
    }

    @MainActor
    func entities(for identifiers: [StudySubjectEntity.ID]) async throws -> [StudySubjectEntity] {
        let subjects = try await suggestedEntities()
        return subjects.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [StudySubjectEntity] {
        let subjects = try await suggestedEntities()
        let search = SubjectStore.normalizedName(string)
        let exactMatches = subjects.filter { SubjectStore.normalizedName($0.name) == search }
        if !exactMatches.isEmpty { return exactMatches }
        return subjects.filter { SubjectStore.normalizedName($0.name).contains(search) }
    }
}
