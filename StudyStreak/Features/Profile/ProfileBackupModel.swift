import Foundation
import Observation

@MainActor @Observable
final class ProfileBackupModel {
    let ownerID: String
    var isImporting = false
    var isConfirmingImport = false
    var isBusy = false
    var exportFile: BackupExportFile?
    var pendingBackup: StudyBackup?
    var notice: String?
    var noticeTitle = "Backup"

    init(ownerID: String) { self.ownerID = ownerID }

    func exportBackup() {
        do {
            let backup = try StudyRuntime.shared.exportBackup(ownerID: ownerID)
            let data = try backup.encoded()
            guard data.count <= 25 * 1024 * 1024 else { throw StudyBackupError.tooLarge }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("StudyStreak-Backup.json")
            do { try data.write(to: url, options: .atomic) }
            catch { try? FileManager.default.removeItem(at: folder); throw error }
            exportFile = BackupExportFile(url: url)
        } catch { show(error, title: "Couldn’t export backup") }
    }

    func selectBackup(_ result: Result<URL, Error>) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let url = try result.get()
            let backup = try await Task.detached { try StudyBackup.read(from: url) }.value
            guard backup.ownerID == ownerID else { throw StudyBackupError.wrongAccount }
            pendingBackup = backup
            isConfirmingImport = true
        } catch { show(error, title: "Couldn’t open backup") }
    }

    func restoreBackup() -> Bool {
        guard let backup = pendingBackup else { return false }
        defer { pendingBackup = nil }
        do {
            try StudyRuntime.shared.restoreBackup(backup, ownerID: ownerID)
            noticeTitle = "Backup restored"
            notice = "Your subjects, study zones, completed sessions and daily goal have been restored."
            return true
        } catch {
            show(error, title: "Couldn’t import backup")
            return false
        }
    }

    private func show(_ error: Error, title: String) {
        noticeTitle = title
        notice = (error as? LocalizedError)?.errorDescription ?? "Please try again. Your existing study data is unchanged."
    }
}

struct BackupExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
