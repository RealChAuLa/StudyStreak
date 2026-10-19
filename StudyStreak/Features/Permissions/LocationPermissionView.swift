import CoreLocation
import SwiftUI
import UIKit

struct LocationPermissionView: View {
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var authorization = LocationAuthorizationService()
    @State private var isWaitingForDecision = false

    var body: some View {
        PermissionScreen(
            page: .location,
            primaryTitle: primaryTitle,
            contextMessage: contextMessage,
            isPrimaryDisabled: isWaitingForDecision,
            onPrimary: requestAccess,
            onSkip: onContinue
        )
        .onChange(of: authorization.authorizationStatus) { _, status in
            if isWaitingForDecision && status != .notDetermined {
                isWaitingForDecision = false
                onContinue()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authorization.refresh()
            }
        }
    }

    private var primaryTitle: String {
        if isWaitingForDecision { return "Requesting Access…" }

        switch authorization.authorizationStatus {
        case .notDetermined: return PermissionPage.location.buttonTitle
        case .denied: return "Open Settings"
        default: return "Continue"
        }
    }

    private var contextMessage: String {
        switch authorization.authorizationStatus {
        case .authorizedAlways:
            "Always access is enabled.\nYour location is never shared with friends."
        case .authorizedWhenInUse:
            "While Using access is enabled.\nAlways access comes with automatic zones."
        case .denied:
            "Location access is off. Enable it in Settings,\nor continue and track sessions manually."
        case .restricted:
            "Location access is restricted on this device.\nYou can still track sessions manually."
        default:
            PermissionPage.location.contextMessage
        }
    }

    private func requestAccess() {
        switch authorization.authorizationStatus {
        case .notDetermined:
            isWaitingForDecision = true
            authorization.requestWhenInUseAccess()
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        default:
            onContinue()
        }
    }
}
