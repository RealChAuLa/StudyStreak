import SwiftData
import SwiftUI

struct StatsView: View {
    var initialPeriod: StatsPeriod = .week
    @Environment(StudySessionTracker.self) private var tracker

    var body: some View {
        StatsContent(ownerID: tracker.ownerID, initialPeriod: initialPeriod).id(tracker.ownerID)
    }
}

private struct StatsContent: View {
    @Environment(StudySessionTracker.self) private var tracker
    @Query private var zones: [StudyZone]
    @Query private var subjects: [StudySubject]
    @State private var period: StatsPeriod = .week
    @State private var zoneToEdit: StudyZone?

    init(ownerID: String, initialPeriod: StatsPeriod) {
        _period = State(initialValue: initialPeriod)
        _zones = Query(filter: #Predicate<StudyZone> { $0.ownerID == ownerID })
        _subjects = Query(filter: #Predicate<StudySubject> { $0.ownerID == ownerID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading.padding(.horizontal, 24)
            Picker("Study period", selection: $period) {
                ForEach(StatsPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented).padding(.horizontal, 24)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                content(at: context.date)
            }
        }
        .padding(.top, 8)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .navigationDestination(item: $zoneToEdit) { zone in ZoneEditorView(zone: zone) }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights").font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
                .accessibilityAddTraits(.isHeader)
            Text("Small sessions, steady progress.")
                .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func content(at now: Date) -> some View {
        let records = tracker.history + (tracker.current.map { [$0] } ?? [])
        let snapshot = StatsAnalytics.snapshot(records: records, period: period, now: now,
                                               goal: tracker.settings.goal(on:))
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if let error = tracker.loadError {
                    loadError(error)
                } else {
                    StatsStudyTimeCard(snapshot: snapshot)
                    StatsSubjectCard(totals: displaySubjects(snapshot.subjects))
                    StatsZoneSection(totals: snapshot.zones, savedZones: zones) { zoneToEdit = $0 }
                    StatsConsistencyCard(weeks: snapshot.weeks)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .refreshable { tracker.reload(); tracker.refreshSettings() }
    }

    private func displaySubjects(_ totals: [StatsSubjectTotal]) -> [StatsSubjectTotal] {
        totals.map { total in
            guard let saved = subjects.first(where: { $0.id == total.id }) else { return total }
            return StatsSubjectTotal(
                subject: SessionSubject(id: saved.id, name: saved.name, colorID: saved.colorID, iconID: saved.iconID),
                seconds: total.seconds
            )
        }
    }

    private func loadError(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couldn’t load your statistics").font(AppTypography.headline).foregroundStyle(AppColors.text)
            Text(message).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
            Button("Try again") { tracker.reload(); tracker.refreshSettings() }
                .font(AppTypography.headline).foregroundStyle(AppColors.primary).frame(minHeight: 44)
        }
        .studySessionCard()
    }
}
