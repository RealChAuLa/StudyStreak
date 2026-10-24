import Foundation
import SwiftData

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var ownerID: String
    var startedAt: Date
    var endedAt: Date?
    var stateRaw: String
    var sourceRaw: String
    var subjectID: UUID
    var subjectName: String
    var subjectColorID: String
    var subjectIconID: String
    var zoneID: UUID?
    var zoneName: String?
    @Relationship(deleteRule: .cascade, inverse: \StudyInterval.session)
    var intervals: [StudyInterval] = []

    init(ownerID: String, subject: SessionSubject, zoneID: UUID?, zoneName: String?, now: Date) {
        id = UUID()
        self.ownerID = ownerID
        startedAt = now
        endedAt = nil
        stateRaw = SessionState.running.rawValue
        sourceRaw = "manual"
        subjectID = subject.id
        subjectName = subject.name
        subjectColorID = subject.colorID
        subjectIconID = subject.iconID
        self.zoneID = zoneID
        self.zoneName = zoneName
    }
}

@Model
final class StudyInterval {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var subjectID: UUID
    var subjectName: String
    var subjectColorID: String
    var subjectIconID: String
    var session: StudySession?

    init(subject: SessionSubject, now: Date) {
        id = UUID()
        startedAt = now
        endedAt = nil
        subjectID = subject.id
        subjectName = subject.name
        subjectColorID = subject.colorID
        subjectIconID = subject.iconID
    }
}
