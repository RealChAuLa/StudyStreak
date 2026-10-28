import Foundation

// Plain values make the backup independent of SwiftData's storage format.
nonisolated struct StudyBackup: Codable, Sendable {
    let format: String
    let version: Int
    let ownerID: String
    let exportedAt: Date
    let subjects: [Subject]
    let zones: [Zone]
    let sessions: [SessionRecord]
    let goals: [DailyGoalChange]

    nonisolated struct Subject: Codable, Sendable {
        let id: UUID
        let name: String
        let colorID: String
        let iconID: String
        let sortIndex: Int
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    nonisolated struct Zone: Codable, Sendable {
        let id: UUID
        let name: String
        let latitude: Double
        let longitude: Double
        let radiusMeters: Double
        let address: String?
        let iconID: String
        let subjectID: UUID?
        let isEnabled: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    var summary: String {
        "\(subjects.count) subjects, \(zones.count) study zones and \(sessions.count) completed sessions."
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func read(from url: URL) throws -> StudyBackup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        // Read at most 25 MB, including when the file comes from a cloud provider.
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let limit = 25 * 1024 * 1024
        let data = try file.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw StudyBackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let backup: StudyBackup
        do { backup = try decoder.decode(StudyBackup.self, from: data) }
        catch { throw StudyBackupError.invalidFile }
        try backup.validate()
        return backup
    }

    func validate() throws {
        guard format == "StudyStreak" else { throw StudyBackupError.invalidFile }
        guard version == 1 else { throw StudyBackupError.unsupportedVersion }
        func validDate(_ date: Date) -> Bool {
            (0...4_102_444_800).contains(date.timeIntervalSince1970)
        }
        let subjectIDs = Set(subjects.map(\.id))
        let zoneIDs = Set(zones.map(\.id))
        guard !ownerID.isEmpty, validDate(exportedAt),
              subjectIDs.count == subjects.count, zoneIDs.count == zones.count,
              Set(sessions.map(\.id)).count == sessions.count else { throw StudyBackupError.invalidFile }
        func validName(_ name: String, max: Int) -> Bool {
            (1...max).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count)
        }
        let names = subjects.map {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        }
        guard Set(names).count == names.count else { throw StudyBackupError.invalidFile }
        for subject in subjects {
            guard validName(subject.name, max: 40), subject.sortIndex >= 0,
                  validDate(subject.createdAt), validDate(subject.updatedAt), subject.createdAt <= subject.updatedAt else { throw StudyBackupError.invalidFile }
        }
        for zone in zones {
            guard validName(zone.name, max: 60), (-90...90).contains(zone.latitude),
                  (-180...180).contains(zone.longitude), (100...500).contains(zone.radiusMeters),
                  zone.subjectID.map({ subjectIDs.contains($0) }) ?? true,
                  validDate(zone.createdAt), validDate(zone.updatedAt), zone.createdAt <= zone.updatedAt else { throw StudyBackupError.invalidFile }
        }
        for session in sessions {
            guard session.state == .completed, let end = session.endedAt,
                  validDate(session.startedAt), validDate(end),
                  end >= session.startedAt, end <= exportedAt.addingTimeInterval(1),
                  !session.needsSubjectConfirmation,
                  SessionSource(rawValue: session.source) != nil,
                  validName(session.subject.name, max: 40) else { throw StudyBackupError.invalidFile }
            var previousEnd = session.startedAt
            for span in session.spans {
                guard let spanEnd = span.endedAt, span.startedAt >= previousEnd,
                      spanEnd >= span.startedAt, spanEnd <= end,
                      validName(span.subject.name, max: 40) else { throw StudyBackupError.invalidFile }
                previousEnd = spanEnd
            }
            // Session snapshots may reference a subject or zone that was later deleted.
        }
        guard Set(goals.map(\.effectiveFrom)).count == goals.count,
              goals.allSatisfy({ validDate($0.effectiveFrom) && (15...240).contains($0.minutes) && $0.minutes.isMultiple(of: 15) }),
              goals.map(\.effectiveFrom) == goals.map(\.effectiveFrom).sorted() else {
            throw StudyBackupError.invalidFile
        }
    }
}

nonisolated enum StudyBackupError: LocalizedError {
    case invalidFile, unsupportedVersion, wrongAccount, activeSession, tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This file isn’t a valid StudyStreak backup. Your data hasn’t been changed."
        case .unsupportedVersion: "This backup uses a different format. Try updating StudyStreak."
        case .wrongAccount: "Sign in to the account that created this backup to restore it."
        case .activeSession: "Finish your current study session before importing a backup."
        case .tooLarge: "Choose a backup smaller than 25 MB."
        }
    }
}
