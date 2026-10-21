import Foundation
import SwiftData

nonisolated enum SubjectStoreError: LocalizedError {
    case signedOut, invalidName, duplicateName, wrongOwner

    var errorDescription: String? {
        switch self {
        case .signedOut: "Please sign in again before changing your subjects."
        case .invalidName: "Use a subject name between 1 and 40 characters."
        case .duplicateName: "You already have a subject with this name."
        case .wrongOwner: "This subject isn’t available for this account."
        }
    }
}

@MainActor
enum SubjectStore {
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func save(name: String, color: SubjectColor, icon: SubjectIcon, isActive: Bool,
                     ownerID: String, editing subject: StudySubject?, in context: ModelContext) throws -> StudySubject {
        guard !ownerID.isEmpty else { throw SubjectStoreError.signedOut }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(trimmed.count) else { throw SubjectStoreError.invalidName }
        if let subject, subject.ownerID != ownerID { throw SubjectStoreError.wrongOwner }
        let owned = try context.fetch(FetchDescriptor<StudySubject>(predicate: #Predicate { $0.ownerID == ownerID }))
        guard !owned.contains(where: { $0.id != subject?.id && normalizedName($0.name) == normalizedName(trimmed) }) else {
            throw SubjectStoreError.duplicateName
        }
        let saved = subject ?? StudySubject(ownerID: ownerID, name: trimmed, colorID: color.rawValue,
            iconID: icon.rawValue, sortIndex: (owned.map(\.sortIndex).max() ?? -1) + 1)
        if subject == nil { context.insert(saved) }
        saved.name = trimmed
        saved.colorID = color.rawValue
        saved.iconID = icon.rawValue
        saved.isActive = isActive
        do { try context.save() }
        catch { context.rollback(); throw error }
        return saved
    }

    static func setActive(_ isActive: Bool, for subject: StudySubject,
                          ownerID: String, in context: ModelContext) throws {
        guard !ownerID.isEmpty else { throw SubjectStoreError.signedOut }
        guard subject.ownerID == ownerID else { throw SubjectStoreError.wrongOwner }
        subject.isActive = isActive
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func delete(_ subject: StudySubject, ownerID: String, in context: ModelContext) throws {
        guard !ownerID.isEmpty else { throw SubjectStoreError.signedOut }
        guard subject.ownerID == ownerID else { throw SubjectStoreError.wrongOwner }
        context.delete(subject)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func reorder(_ subjects: [StudySubject], ownerID: String, in context: ModelContext) throws {
        guard !ownerID.isEmpty else { throw SubjectStoreError.signedOut }
        guard subjects.allSatisfy({ $0.ownerID == ownerID }) else { throw SubjectStoreError.wrongOwner }
        for (index, subject) in subjects.enumerated() { subject.sortIndex = index }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
