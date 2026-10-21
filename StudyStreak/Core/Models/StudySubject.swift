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

    init(ownerID: String, name: String, colorID: String, iconID: String, sortIndex: Int) {
        id = UUID()
        self.ownerID = ownerID
        self.name = name
        self.colorID = colorID
        self.iconID = iconID
        self.sortIndex = sortIndex
        createdAt = .now
    }
}
