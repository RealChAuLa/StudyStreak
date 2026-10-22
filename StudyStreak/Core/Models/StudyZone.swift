import Foundation
import SwiftData

@Model
final class StudyZone {
    @Attribute(.unique) var id: UUID
    var ownerID: String
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var address: String?
    // Stores the actual selected icon, including icons from the extra icon menu.
    var iconID: String
    var defaultSubject: StudySubject?
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(ownerID: String, name: String, latitude: Double, longitude: Double,
         radiusMeters: Double, iconID: String, address: String? = nil,
         defaultSubject: StudySubject? = nil, isEnabled: Bool = true) {
        id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.iconID = iconID
        self.address = address
        self.defaultSubject = defaultSubject
        self.isEnabled = isEnabled
        createdAt = .now
        updatedAt = createdAt
    }
}
