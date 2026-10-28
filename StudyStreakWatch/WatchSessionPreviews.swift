import SwiftUI

private enum WatchSessionPreview {
    static let subject = WatchSubject(id: UUID(), name: "Mathematics")
    static let ready = WatchSessionSnapshot(accountID: "preview", generatedAt: .now,
        access: .ready, subjects: [subject, WatchSubject(id: UUID(), name: "Computer Science")],
        current: nil)
    static let studying = WatchSessionSnapshot(accountID: "preview", generatedAt: .now,
        access: .ready, subjects: [subject],
        current: WatchStudySession(id: UUID(), subject: subject, elapsedSeconds: 1458,
                                  isRunning: true, measuredAt: .now))
}

#Preview("Ready to study") {
    WatchSessionView(model: WatchSessionViewModel(preview: WatchSessionPreview.ready))
        .environment(\.colorScheme, .dark)
}

#Preview("Session in progress") {
    WatchSessionView(model: WatchSessionViewModel(preview: WatchSessionPreview.studying))
        .environment(\.colorScheme, .dark)
}

