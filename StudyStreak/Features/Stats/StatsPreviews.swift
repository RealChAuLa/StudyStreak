import SwiftData
import SwiftUI

private struct StatsPreviewHost: View {
    var period: StatsPeriod = .week
    var isEmpty = false
    @State private var container: ModelContainer?
    @State private var tracker: StudySessionTracker?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let container, let tracker {
                NavigationStack { StatsView(initialPeriod: period) }
                    .environment(tracker)
                    .environment(\.studyUserID, "stats-preview")
                    .modelContainer(container)
                    .tint(AppColors.primary)
            } else if let errorMessage {
                ContentUnavailableView("Couldn’t prepare preview", systemImage: "chart.bar",
                                       description: Text(errorMessage))
            } else {
                ProgressView()
            }
        }
        .task { prepare() }
    }

    private func prepare() {
        guard container == nil, errorMessage == nil else { return }
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let saved = try ModelContainer(for: StudySubject.self, StudyZone.self,
                                           StudySession.self, StudyInterval.self, configurations: configuration)
            if !isEmpty { seed(in: saved.mainContext) }
            try saved.mainContext.save()
            tracker = StudySessionTracker(container: saved, ownerID: "stats-preview")
            container = saved
        } catch { errorMessage = error.localizedDescription }
    }

    private func seed(in context: ModelContext) {
        let subjects = [
            StudySubject(ownerID: "stats-preview", name: "Mathematics", colorID: "blue", iconID: "atom", sortIndex: 0),
            StudySubject(ownerID: "stats-preview", name: "Physics", colorID: "purple", iconID: "book", sortIndex: 1),
            StudySubject(ownerID: "stats-preview", name: "Computer Science", colorID: "teal", iconID: "code", sortIndex: 2)
        ]
        for subject in subjects { context.insert(subject) }
        let zone = StudyZone(ownerID: "stats-preview", name: "Library", latitude: 6.9271,
                             longitude: 79.8612, radiusMeters: 150, iconID: "library", defaultSubject: subjects[0])
        context.insert(zone)
        let now = Date.now
        let calendar = Calendar.current
        for offset in 0..<84 where offset < 7 || offset.isMultiple(of: 3) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now),
                  let start = calendar.date(bySettingHour: 8 + offset % 4, minute: 30, second: 0, of: day) else { continue }
            let end = min(now, start.addingTimeInterval(Double(30 + offset % 5 * 15) * 60))
            guard end > start else { continue }
            let saved = subjects[offset % subjects.count]
            let subject = SessionSubject(id: saved.id, name: saved.name, colorID: saved.colorID, iconID: saved.iconID)
            let session = StudySession(ownerID: "stats-preview", subject: subject,
                                       zoneID: offset.isMultiple(of: 4) ? nil : zone.id,
                                       zoneName: offset.isMultiple(of: 4) ? nil : zone.name, now: start)
            let interval = StudyInterval(subject: subject, now: start)
            interval.endedAt = end
            session.intervals = [interval]
            session.stateRaw = SessionState.completed.rawValue
            session.endedAt = end
            context.insert(session)
        }
    }
}

#Preview("22 · Insights / week") { StatsPreviewHost() }
#Preview("23 · Insights / dark") { StatsPreviewHost().preferredColorScheme(.dark) }
#Preview("24 · Insights / day") { StatsPreviewHost(period: .day) }
#Preview("25 · Insights / month") { StatsPreviewHost(period: .month) }
#Preview("Insights · Empty") { StatsPreviewHost(isEmpty: true) }
#Preview("Insights · SE", traits: .fixedLayout(width: 375, height: 667)) { StatsPreviewHost() }
