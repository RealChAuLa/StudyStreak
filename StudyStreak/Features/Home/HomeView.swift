import Charts
import SwiftUI

struct HomeView: View {
    let displayName: String
    @Environment(StudySessionTracker.self) private var tracker
    @Environment(StudyRuntime.self) private var runtime: StudyRuntime?
    @State private var isHomeVisible = false
    @State private var automaticSheet: AutomaticSheet?
    @State private var queuedAutomaticSheet: AutomaticSheet?
    @State private var lastAutomaticSessionID: UUID?
    @State private var isStarting = false
    @State private var isShowingSession = false
    @State private var openAfterStart = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: tracker.current?.state == .running ? 1 : 60)) { context in
            dashboard(at: context.date)
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .sheet(isPresented: $isStarting, onDismiss: {
            // Wait for the picker to close before presenting the active session.
            if openAfterStart && tracker.current != nil { isShowingSession = true }
            openAfterStart = false
            presentAutomaticConfirmation()
        }) {
            SessionSelectionView(ownerID: tracker.ownerID) {
                openAfterStart = true
                isStarting = false
            }
            .presentationDetents([.height(523), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .fullScreenCover(isPresented: $isShowingSession, onDismiss: presentAutomaticConfirmation) {
            SessionFlowView()
        }
        .sheet(item: $automaticSheet, onDismiss: automaticSheetDismissed) { route in
            if let current = tracker.current, current.id == route.sessionID {
                switch route {
                case .confirmation:
                    AutomaticSessionConfirmationView(session: current, onConfirm: {
                        confirm(current.id)
                        automaticSheet = nil
                    }, onChangeSubject: {
                        queuedAutomaticSheet = .changeSubject(current.id)
                        confirm(current.id)
                        automaticSheet = nil
                    })
                    .presentationDetents([.height(320), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                case .changeSubject:
                    SessionSelectionView(ownerID: tracker.ownerID, existing: current) { automaticSheet = nil }
                        .presentationDetents([.height(523), .large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                }
            }
        }
        .onAppear {
            isHomeVisible = true
            tracker.refreshSettings()
            tracker.requestSync()
            updateConfirmationAvailability()
            presentAutomaticConfirmation()
        }
        .onDisappear {
            isHomeVisible = false
            runtime?.homeCanShowConfirmation = false
        }
        .onChange(of: isStarting) { _, _ in updateConfirmationAvailability() }
        .onChange(of: isShowingSession) { _, _ in updateConfirmationAvailability() }
        .onChange(of: tracker.current) { _, current in
            if let route = automaticSheet,
               current?.id != route.sessionID || (route.isConfirmation && (current?.state != .running || current?.needsSubjectConfirmation != true)) {
                queuedAutomaticSheet = nil
                automaticSheet = nil
            }
            presentAutomaticConfirmation()
        }
    }

    private func dashboard(at date: Date) -> some View {
        let metrics = tracker.metrics(at: date)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                greeting(at: date, streak: metrics.streak).padding(.bottom, 8)
                if let error = tracker.loadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                        Button("Try again") { tracker.reload(); runtime?.refresh() }
                            .font(AppTypography.headline).foregroundStyle(AppColors.primary)
                            .frame(minHeight: 44)
                    }
                    .studySessionCard()
                }
                if let current = tracker.current { currentSession(current, at: date) }
                else { readyCard }
                NavigationLink {
                    DailyGoalView(preferences: RoutinePreferences(ownerID: tracker.ownerID))
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    todayCard(metrics)
                }
                .buttonStyle(.plain)
                recentSessions
                weekCard(metrics, now: date)
                if let error = tracker.syncError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                        Button("Retry sync") { tracker.requestSync() }
                            .font(AppTypography.subheadline).foregroundStyle(AppColors.primary)
                            .frame(minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func greeting(at date: Date, streak: Int) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingText(at: date)),").font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                Text(displayName).font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Image("HomeStreakFlame").resizable().scaledToFit().frame(width: 24, height: 24)
                    .foregroundStyle(AppColors.accent).accessibilityHidden(true)
                VStack(spacing: 0) {
                    Text("\(streak)")
                        .font(.custom("GoogleSans-Bold", size: 26, relativeTo: .title2))
                        .foregroundStyle(AppColors.text)
                    Text(streak == 1 ? "day" : "days")
                        .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(AppColors.warm, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
        }
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image("HomeFocusBook").resizable().scaledToFit().frame(width: 24, height: 24)
                    .foregroundStyle(AppColors.primary).accessibilityHidden(true)
                Text("Make room for a little focus.")
                    .font(AppTypography.headline).foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "Start a Session") {
                openAfterStart = false
                isStarting = true
            }
            .disabled(tracker.loadError != nil)
        }
        .studySessionCard()
    }

    private func currentSession(_ session: SessionRecord, at date: Date) -> some View {
        Button { isShowingSession = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SessionActivityDot(isRunning: session.state == .running)
                    Text(session.state == .paused ? "Session paused"
                         : session.isAutomatic ? "Currently in \(session.zoneName ?? "your study zone")"
                         : session.zoneName.map { "Studying at \($0)" } ?? "Manual session")
                        .font(AppTypography.subheadline).foregroundStyle(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Image("SessionChevron").resizable().scaledToFit().frame(width: 16, height: 16)
                        .foregroundStyle(AppColors.secondary).accessibilityHidden(true)
                    Spacer(minLength: 0)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        currentTimer(session, at: date)
                        Spacer(minLength: 0)
                        SessionSubjectPill(subject: session.subject)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        currentTimer(session, at: date)
                        SessionSubjectPill(subject: session.subject)
                    }
                }
                Text(session.state == .paused ? "Take a breath. Resume when you’re ready."
                     : "A little focus is adding up. Keep going.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .studySessionCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens session controls")
    }

    private func currentTimer(_ session: SessionRecord, at date: Date) -> some View {
        Text(StudyTime.clock(session.elapsed(at: date)))
            .font(AppTypography.largeTitle).foregroundStyle(AppColors.text)
            .monospacedDigit().fixedSize()
    }

    private func todayCard(_ metrics: HomeStudyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Today").font(AppTypography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(StudyTime.duration(metrics.todaySeconds)).font(AppTypography.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(AppColors.text)
            ProgressView(value: metrics.progress).tint(AppColors.primary)
                .accessibilityLabel("Daily study goal")
                .accessibilityValue("\(Int(metrics.progress * 100)) percent")
            Text(metrics.goalMessage)
                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .studySessionCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Recent sessions").font(AppTypography.title2).foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                NavigationLink {
                    SessionHistoryView()
                } label: {
                    Text("See all").font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.primary).frame(minHeight: 44)
                }
                .accessibilityLabel("See all study sessions")
            }
            if tracker.history.isEmpty {
                Text("Your first completed session will appear here.")
                    .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            } else {
                ForEach(Array(tracker.history.prefix(3))) { record in
                    NavigationLink {
                        SessionSavedView(record: record)
                    } label: {
                        SessionHistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func weekCard(_ metrics: HomeStudyMetrics, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This Week").font(AppTypography.headline).foregroundStyle(AppColors.text)
                Spacer()
                Text(StudyTime.duration(metrics.weekSeconds))
                    .font(AppTypography.caption.weight(.semibold)).foregroundStyle(AppColors.primary)
            }
            Chart(metrics.days) { day in
                BarMark(x: .value("Day", day.date, unit: .day),
                        y: .value("Study minutes", day.seconds / 60), width: .fixed(25))
                    .cornerRadius(4)
                    .foregroundStyle(Calendar.current.isDate(day.date, inSameDayAs: now)
                                     ? AppColors.primary : AppColors.Subject.blue)
            }
            .chartYScale(domain: 0...max(30, (metrics.days.map { $0.seconds / 60 }.max() ?? 0) * 1.15))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: metrics.days.map(\.date)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 72)
            .accessibilityLabel("Study time this week")
        }
        .studySessionCard()
    }

    private enum AutomaticSheet: Identifiable {
        case confirmation(UUID), changeSubject(UUID)
        var sessionID: UUID {
            switch self { case .confirmation(let id), .changeSubject(let id): id }
        }
        var isConfirmation: Bool { if case .confirmation = self { true } else { false } }
        var id: String { "\(sessionID.uuidString).\(isConfirmation ? "confirmation" : "picker")" }
    }

    private func updateConfirmationAvailability() {
        runtime?.homeCanShowConfirmation = isHomeVisible && !isStarting && !isShowingSession
    }

    private func presentAutomaticConfirmation() {
        guard isHomeVisible, !isStarting, !isShowingSession, automaticSheet == nil,
              queuedAutomaticSheet == nil, let current = tracker.current,
              current.isAutomatic, current.state == .running, current.needsSubjectConfirmation else { return }
        guard let expiry = current.confirmationExpiresAt, expiry > .now else {
            confirm(current.id)
            return
        }
        lastAutomaticSessionID = current.id
        automaticSheet = .confirmation(current.id)
    }

    private func automaticSheetDismissed() {
        let previousID = lastAutomaticSessionID
        lastAutomaticSessionID = nil
        if let next = queuedAutomaticSheet {
            queuedAutomaticSheet = nil
            if tracker.current?.id == next.sessionID {
                lastAutomaticSessionID = next.sessionID
                automaticSheet = next
            }
        } else if let previousID, tracker.current?.id == previousID {
            confirm(previousID)
        }
    }

    private func confirm(_ id: UUID) {
        if let runtime { runtime.confirm(id) }
        else { try? tracker.confirmSubject(sessionID: id) }
    }

    private func greetingText(at date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
