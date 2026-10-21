import Foundation
import SwiftData

@Model
final class StudySubject {
    @Attribute(.unique) var id: UUID
    var ownerID: String
    var name: String
    var colorID: String
    var iconID: String
    var sortIndex: Int
    var createdAt: Date
    // A stored default keeps existing subjects active when the schema is updated.
    var isActive: Bool = true

    init(ownerID: String, name: String, colorID: String, iconID: String, sortIndex: Int, isActive: Bool = true) {
        id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.colorID = colorID
        self.iconID = iconID
        self.sortIndex = sortIndex
        self.isActive = isActive
        createdAt = .now
    }
}
