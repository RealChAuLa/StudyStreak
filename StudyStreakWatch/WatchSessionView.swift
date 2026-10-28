import SwiftUI

struct WatchSessionView: View {
    @ObservedObject var model: WatchSessionViewModel

    private var navigationTitle: String {
        switch model.screen {
        case .subjects: "‹ Subjects"
        case .confirmStop: "End session"
        case .unavailable: "Connection"
        case .stopNotConfirmed: "Connection lost"
        default: "StudyStreak"
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    content(compact: geometry.size.width < 174)
                        .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 12))
                        .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, 10)
            }
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.screen == .subjects {
                        Button(action: model.cancelSubjectSelection) {
                            Text(navigationTitle).font(WatchTypography.small)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                    } else {
                        Text(navigationTitle).font(WatchTypography.small)
                    }
                }
            }
            .tint(AppColors.primary)
        }
    }

    @ViewBuilder
    private func content(compact: Bool) -> some View {
        switch model.screen {
        case .loading:
            VStack(spacing: 8) {
                ProgressView().tint(AppColors.primary)
                Text("Connecting to iPhone…")
                    .font(WatchTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
        case .ready:
            if let subject = model.selectedSubject {
                WatchReadyView(subject: subject, isStarting: model.pendingAction == .start,
                               chooseSubject: model.chooseSubject, start: model.start)
            }
        case .subjects:
            VStack(spacing: 8) {
                ForEach(model.snapshot.subjects) { subject in
                    WatchSubjectButton(subject: subject) { model.select(subject) }
                }
            }
        case .active:
            if let session = model.snapshot.current {
                WatchActiveSessionView(session: session, compact: compact, stop: model.confirmStop)
            }
        case .confirmStop:
            if let session = model.sessionToStop ?? model.snapshot.current {
                WatchStopConfirmationView(session: session, isSaving: model.pendingAction == .stop,
                                          save: model.stop, cancel: model.keepStudying)
            }
        case .saved:
            if let session = model.savedSession {
                WatchSavedSessionView(session: session, done: model.done)
            }
        case .unavailable:
            WatchMessageView(imageName: "WatchPhone", title: "iPhone unavailable",
                detail: "Connect your iPhone,\nthen try again.", buttonTitle: "Try again",
                isBusy: model.pendingAction != nil, retry: model.refresh)
        case .stopNotConfirmed:
            WatchMessageView(title: "Stop not confirmed", detail: "Your session may\nstill be running.",
                footer: "Check your iPhone.", isWarning: true, buttonTitle: "Check status",
                isBusy: model.pendingAction != nil, retry: model.refresh)
        case .noSubjects:
            WatchMessageView(imageName: "WatchBook", title: "Add a subject",
                detail: "Use StudyStreak on\nyour iPhone to begin.", buttonTitle: "Refresh",
                buttonStyle: .secondary, isBusy: model.pendingAction != nil, retry: model.refresh)
        case .phoneSetup:
            WatchMessageView(imageName: "WatchBook", title: "Open your iPhone",
                detail: model.message, buttonTitle: "Refresh",
                isBusy: model.pendingAction != nil, retry: model.refresh)
        }
    }
}

