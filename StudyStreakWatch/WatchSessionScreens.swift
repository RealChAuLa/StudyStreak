import SwiftUI

struct WatchReadyView: View {
    let subject: WatchSubject
    let isStarting: Bool
    let chooseSubject: () -> Void
    let start: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("A little focus.")
                .font(WatchTypography.title)
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.center)
            Spacer(minLength: 6)
            WatchSubjectButton(subject: subject, action: chooseSubject)
                .disabled(isStarting)
            Spacer(minLength: 6)
            WatchActionButton(title: isStarting ? "Starting…" : "Start session",
                              isBusy: isStarting, action: start)
            Spacer(minLength: 6)
            WatchConnectionLabel(title: "iPhone connected")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WatchActiveSessionView: View {
    let session: WatchStudySession
    let compact: Bool
    let stop: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                if session.isRunning {
                    WatchConnectionLabel(title: "Studying")
                } else {
                    Text("Paused on iPhone")
                        .font(WatchTypography.small)
                        .foregroundStyle(AppColors.accent)
                }
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(WatchTime.clock(session.elapsed(at: timeline.date)))
                        .font(WatchTypography.timer(compact: compact))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Study time")
                        .accessibilityValue(WatchTime.duration(session.elapsed(at: timeline.date)))
                }
                Text(session.subject.name)
                    .font(WatchTypography.body)
                    .foregroundStyle(AppColors.Subject.blue)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            WatchActionButton(title: "Stop session", style: .destructive, action: stop)
        }
    }
}

struct WatchStopConfirmationView: View {
    let session: WatchStudySession
    let isSaving: Bool
    let save: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 4) {
                Text("Save your focus?")
                    .font(WatchTypography.button)
                    .foregroundStyle(AppColors.text)
                Text(WatchTime.duration(session.elapsed(at: .now)))
                    .font(WatchTypography.caption)
                    .foregroundStyle(AppColors.secondary)
            }
            .multilineTextAlignment(.center)
            Spacer(minLength: 6)
            WatchActionButton(title: isSaving ? "Saving…" : "Stop & save",
                              style: .destructive, isBusy: isSaving, action: save)
            WatchActionButton(title: "Keep studying", style: .secondary,
                              isBusy: isSaving, action: cancel)
        }
    }
}

struct WatchSavedSessionView: View {
    let session: WatchStudySession
    let done: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Image("WatchSaved")
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                Text("Time well spent.")
                    .font(WatchTypography.button)
                    .foregroundStyle(AppColors.text)
                Text(WatchTime.duration(session.elapsedSeconds))
                    .font(WatchTypography.title)
                    .foregroundStyle(AppColors.accent)
                Text(session.subject.name)
                    .font(WatchTypography.caption)
                    .foregroundStyle(AppColors.Subject.blue)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            WatchActionButton(title: "Done", action: done)
        }
    }
}

struct WatchMessageView: View {
    var imageName: String? = nil
    let title: String
    let detail: String
    var footer: String? = nil
    var isWarning = false
    let buttonTitle: String
    var buttonStyle: WatchActionButton.Style = .primary
    var isBusy = false
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if let imageName {
                    Image(imageName)
                        .resizable().scaledToFit()
                        .frame(width: 26, height: 26)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(WatchTypography.button)
                    .foregroundStyle(isWarning ? AppColors.accent : AppColors.text)
                Text(detail)
                    .font(WatchTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                if let footer {
                    Text(footer)
                        .font(WatchTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            WatchActionButton(title: isBusy ? "Connecting…" : buttonTitle,
                              style: buttonStyle, isBusy: isBusy, action: retry)
        }
    }
}

