import SwiftUI
import UIKit
import UserNotifications

struct NotificationPermissionView: View {
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorization = NotificationAuthorizationService()
    @State private var isRequesting = false
    @State private var showsRequestError = false

    var body: some View {
        PermissionScreen(
            page: .notifications,
            primaryTitle: primaryTitle,
            contextMessage: contextMessage,
            isPrimaryDisabled: isRequesting || !authorization.hasLoadedSettings,
            onPrimary: requestAccess,
            onSkip: onContinue
        )
        .task {
            await authorization.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await authorization.refresh() }
            }
        }
        .alert("Couldn’t request notifications", isPresented: $showsRequestError) {
            Button("Try Again", action: requestAccess)
            Button("Maybe Later", role: .cancel, action: onContinue)
        } message: {
            Text("Please try again. You can also continue without reminders and enable them later in Settings.")
        }
    }

    private var primaryTitle: String {
        if isRequesting { return "Requesting Access…" }
        if !authorization.hasLoadedSettings { return "Checking Access…" }

        switch authorization.authorizationStatus {
        case .notDetermined: return PermissionPage.notifications.buttonTitle
        case .denied: return "Open Settings"
        default: return "Continue"
        }
    }

    private var contextMessage: String {
        switch authorization.authorizationStatus {
        case .denied:
            "Notifications are off. Enable them in Settings,\nor continue without reminders."
        case .authorized:
            "Notifications are enabled.\nYou can change them anytime in Settings."
        case .provisional, .ephemeral:
            "Quiet notifications are enabled.\nYou can change delivery options in Settings."
        default:
            PermissionPage.notifications.contextMessage
        }
    }

    private func requestAccess() {
        switch authorization.authorizationStatus {
        case .notDetermined:
            isRequesting = true
            Task {
                defer { isRequesting = false }

                do {
                    try await authorization.requestAccess()
                    onContinue()
                } catch {
                    showsRequestError = true
                }
            }
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        default:
            onContinue()
        }
    }
}
