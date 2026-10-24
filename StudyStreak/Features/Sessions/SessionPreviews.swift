import SwiftData
import SwiftUI

// Preview records are created in memory and never uploaded.
private struct SessionPreviewHost: View {
    var hasActiveSession = false
    @State private var container: ModelContainer?
    @State private var tracker: StudySessionTracker?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let container, let tracker {
                NavigationStack { HomeView(displayName: "Devinda") }
                    .environment(tracker)
                    .modelContainer(container)
                    .tint(AppColors.primary)
            } else if let errorMessage {
                ContentUnavailableView("Couldn’t prepare preview", systemImage: "book",
                                       description: Text(errorMessage))
            } else {
                ProgressView()
            }
        }
        .task {
            guard container == nil, errorMessage == nil else { return }
            do {
                let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let saved = try ModelContainer(for: StudySubject.self, StudyZone.self,
                                               StudySession.self, StudyInterval.self, configurations: configuration)
                let context = ModelContext(saved)
                let subject = StudySubject(ownerID: "preview", name: "Mathematics",
                                           colorID: "blue", iconID: "atom", sortIndex: 0)
                context.insert(subject)
                try context.save()
                let tracker = StudySessionTracker(container: saved, ownerID: "preview")
                if hasActiveSession {
                    let now = Date.now
                    try tracker.start(subjectID: subject.id, zoneID: nil, now: now.addingTimeInterval(-7200))
                    try tracker.finish(now: now.addingTimeInterval(-4500))
                    try tracker.start(subjectID: subject.id, zoneID: nil, now: now.addingTimeInterval(-1500))
                }
                self.container = saved
                self.tracker = tracker
            } catch { errorMessage = error.localizedDescription }
        }
    }
}

#Preview("Home · Ready") { SessionPreviewHost() }
#Preview("Home · Studying") { SessionPreviewHost(hasActiveSession: true) }
#Preview("Home · Dark") { SessionPreviewHost(hasActiveSession: true).preferredColorScheme(.dark) }
#Preview("Home · SE", traits: .fixedLayout(width: 375, height: 667)) {
    SessionPreviewHost(hasActiveSession: true)
}
