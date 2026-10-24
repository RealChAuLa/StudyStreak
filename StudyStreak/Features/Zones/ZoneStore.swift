import CoreLocation
import Foundation
import SwiftData

nonisolated enum ZoneStoreError: LocalizedError {
    case signedOut, invalidName, invalidLocation, invalidRadius, invalidIcon, unavailableSubject, wrongOwner

    var errorDescription: String? {
        switch self {
        case .signedOut: "Please sign in again before changing your study zones."
        case .invalidName: "Use a zone name between 1 and 60 characters."
        case .invalidLocation: "Choose a valid location on the map."
        case .invalidRadius: "Choose a radius between 100 and 500 metres."
        case .invalidIcon: "Choose an icon for your study zone."
        case .unavailableSubject: "Choose one of your active subjects before saving this zone."
        case .wrongOwner: "This study zone isn’t available for this account."
        }
    }
}

@MainActor
enum ZoneStore {
    @discardableResult
    static func save(_ draft: ZoneEditorDraft, ownerID: String, editing zone: StudyZone?,
                     in context: ModelContext) throws -> StudyZone {
        guard !ownerID.isEmpty else { throw ZoneStoreError.signedOut }
        if let zone, zone.ownerID != ownerID { throw ZoneStoreError.wrongOwner }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(name.count) else { throw ZoneStoreError.invalidName }
        guard CLLocationCoordinate2DIsValid(draft.coordinate), draft.coordinate.latitude.isFinite,
              draft.coordinate.longitude.isFinite else { throw ZoneStoreError.invalidLocation }
        guard draft.radius.isFinite, (100...500).contains(draft.radius) else { throw ZoneStoreError.invalidRadius }
        guard ZoneIcon.isSupported(draft.iconID) else { throw ZoneStoreError.invalidIcon }
        let subjects = try context.fetch(FetchDescriptor<StudySubject>(predicate: #Predicate { $0.ownerID == ownerID && $0.isActive }))
        guard let subject = subjects.first(where: { $0.id == draft.subjectID }) else { throw ZoneStoreError.unavailableSubject }

        let saved = zone ?? StudyZone(ownerID: ownerID, name: name, latitude: draft.coordinate.latitude,
            longitude: draft.coordinate.longitude, radiusMeters: draft.radius, iconID: draft.iconID)
        if zone == nil { context.insert(saved) }
        saved.name = name
        saved.latitude = draft.coordinate.latitude
        saved.longitude = draft.coordinate.longitude
        saved.radiusMeters = draft.radius
        saved.iconID = draft.iconID
        saved.address = draft.address
        saved.defaultSubject = subject
        saved.updatedAt = .now
        do { try context.save() }
        catch { context.rollback(); throw error }
        return saved
    }

    static func setEnabled(_ value: Bool, for zone: StudyZone, ownerID: String, in context: ModelContext) throws {
        guard !ownerID.isEmpty else { throw ZoneStoreError.signedOut }
        guard zone.ownerID == ownerID else { throw ZoneStoreError.wrongOwner }
        if value {
            guard let subject = zone.defaultSubject, subject.ownerID == ownerID, subject.isActive else {
                throw ZoneStoreError.unavailableSubject
            }
        }
        zone.isEnabled = value
        zone.updatedAt = .now
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    static func delete(_ zone: StudyZone, ownerID: String, in context: ModelContext) throws {
        guard !ownerID.isEmpty else { throw ZoneStoreError.signedOut }
        guard zone.ownerID == ownerID else { throw ZoneStoreError.wrongOwner }
        context.delete(zone)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
