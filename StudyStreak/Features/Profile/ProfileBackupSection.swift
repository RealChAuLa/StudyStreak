import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileBackupSection: View {
    @State private var model: ProfileBackupModel
    var onRestored: () -> Void = { }

    init(ownerID: String, onRestored: @escaping () -> Void = { }) {
        _model = State(initialValue: ProfileBackupModel(ownerID: ownerID))
        self.onRestored = onRestored
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                Button { model.exportBackup() } label: {
                    row("Export backup", subtitle: "Save a copy of your study data", icon: "ProfileBackupExport")
                }
                Divider().overlay(AppColors.border)
                Button { model.isImporting = true } label: {
                    row("Import backup", subtitle: "Restore from a saved backup", icon: "ProfileBackupImport")
                }
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)
            .padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))

            Text("Includes subjects, study zones, completed sessions and your daily goal. Importing replaces the study data on this device.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.isBusy { ProgressView("Reading backup…").font(AppTypography.caption) }
        }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: [.json]) { result in
            Task { await model.selectBackup(result) }
        }
        .sheet(item: $model.exportFile) { file in
            BackupShareSheet(url: file.url)
        }
        .alert("Replace your study data?", isPresented: $model.isConfirmingImport) {
            Button("Cancel", role: .cancel) { model.pendingBackup = nil }
            Button("Replace data", role: .destructive) {
                if model.restoreBackup() { onRestored() }
            }
        } message: {
            Text(importSummary)
        }
        .alert(model.noticeTitle, isPresented: Binding(
            get: { model.notice != nil }, set: { if !$0 { model.notice = nil } }
        )) {
            Button("OK", role: .cancel) { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
    }

    private var importSummary: String {
        guard let backup = model.pendingBackup else { return "" }
        return "Backup from \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened)).\n\n\(backup.summary)\n\nThis replaces this account’s local study data and daily goal. Export a backup first if you want to keep your current data."
    }

    private func row(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(icon).resizable().scaledToFit().frame(width: 22, height: 22)
                .foregroundStyle(AppColors.primary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppTypography.body).foregroundStyle(AppColors.text)
                Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image("ProfileChevron").resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct BackupShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
