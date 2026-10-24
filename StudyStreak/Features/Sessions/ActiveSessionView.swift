import SwiftUI

struct SessionFlowView: View {
    @Environment(StudySessionTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss
    @State private var saved: SessionRecord?

    var body: some View {
        NavigationStack {
            Group {
                if let saved {
                    SessionSavedView(record: saved, onDone: { dismiss() })
                } else if let session = tracker.current {
                    ActiveSessionView(session: session) { saved = $0 }
                } else {
                    ContentUnavailableView("Ready when you are", systemImage: "book",
                                           description: Text("Start your next session from Home."))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                        }
                }
            }
        }
        .tint(AppColors.primary)
    }
}

struct ActiveSessionView: View {
    let session: SessionRecord
    let onFinished: (SessionRecord) -> Void
    @Environment(StudySessionTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss
    @Environment(StudyRuntime.self) private var runtime: StudyRuntime?
    @State private var isChangingSubject = false
    @State private var errorMessage: String?

    private var isRunning: Bool { session.state == .running }

    var body: some View {
        TimelineView(.periodic(from: .now, by: isRunning ? 1 : 60)) { context in
            ScrollView {
                VStack(spacing: 24) {
                    Text(isRunning ? "One thing at a time." : "Take a breath. We’ll wait.")
                        .font(AppTypography.body).foregroundStyle(AppColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 16)
                    timer(at: context.date)
                    Text("of a 60-minute focus block")
                        .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                    Button { isChangingSubject = true } label: {
                        SessionSubjectPill(subject: session.subject).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change subject. \(session.subject.name)")
                    HStack(spacing: 8) {
                        Image("SessionLocation").resizable().scaledToFit().frame(width: 16, height: 16)
                            .foregroundStyle(AppColors.success).accessibilityHidden(true)
                        Text(session.isAutomatic ? "Auto-started at \(session.zoneName ?? "your study zone")"
                             : "Manual session · \(session.zoneName ?? "Not in a zone")")
                            .font(AppTypography.subheadline).foregroundStyle(AppColors.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let errorMessage {
                        Text(errorMessage).font(AppTypography.subheadline).foregroundStyle(AppColors.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack {
                AppColors.background
                session.subject.color.opacity(0.07)
            }
            .ignoresSafeArea()
        }
        .navigationTitle(isRunning ? "Focus time" : "Session paused")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Home", systemImage: "chevron.left") { dismiss() }
                    .labelStyle(.iconOnly).accessibilityLabel("Back to Home")
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onChange(of: session.id) { _, _ in isChangingSubject = false; errorMessage = nil }
        .sheet(isPresented: $isChangingSubject) {
            SessionSelectionView(ownerID: tracker.ownerID, existing: session) { isChangingSubject = false }
                .presentationDetents([.height(523), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
    }

    private func timer(at date: Date) -> some View {
        let elapsed = session.elapsed(at: date)
        return ZStack {
            Circle().stroke(AppColors.primary.opacity(0.12), lineWidth: 8)
            Circle().trim(from: 0, to: min(1, elapsed / 3600))
                .stroke(isRunning ? AppColors.primary : AppColors.secondary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 8) {
                Text(StudyTime.clock(elapsed))
                    .font(.custom("GoogleSans-Regular", size: 56, relativeTo: .largeTitle))
                    .foregroundStyle(AppColors.text)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.45)
                Text(isRunning ? "FOCUSING" : "PAUSED")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(isRunning ? AppColors.primary : AppColors.secondary)
            }
            .padding(16)
        }
        .frame(width: 253, height: 253)
        .padding(4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Study time \(StudyTime.clock(elapsed)). \(isRunning ? "Focusing" : "Paused").")
    }

    private var controls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                Button(isRunning ? "Pause" : "Resume", action: togglePause)
                    .disabled(!isRunning && !canResume)
                    .opacity(!isRunning && !canResume ? 0.5 : 1)
                    .font(AppTypography.headline).foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(AppColors.tint, in: RoundedRectangle(cornerRadius: 16))
                Button("Stop", role: .destructive, action: finish)
                    .font(AppTypography.headline).foregroundStyle(AppColors.danger)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(AppColors.warm, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            Text(resumeHint)
                .font(AppTypography.caption).foregroundStyle(AppColors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(AppColors.background)
    }

    private var resumeHint: String {
        if !isRunning && !canResume {
            if runtime?.zones.isReady != true {
                return "Check automatic tracking in Zones, or stop and start a manual session."
            }
            return "Return to your zone to resume, or stop and start a manual session."
        }
        return session.isAutomatic ? "Your progress is saved when you leave your zone."
            : "Your progress stays saved when you return to Home."
    }

    private var canResume: Bool { runtime?.canResume(session) ?? !session.isAutomatic }

    private func togglePause() {
        do {
            if isRunning { try tracker.pause() }
            else if canResume { try tracker.resume() }
            errorMessage = nil
        } catch { errorMessage = SessionTrackingError.message(for: error) }
    }

    private func finish() {
        do { onFinished(try tracker.finish()) }
        catch { errorMessage = SessionTrackingError.message(for: error) }
    }
}
