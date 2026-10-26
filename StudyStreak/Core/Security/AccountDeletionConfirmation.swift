import Foundation
import LocalAuthentication

@MainActor
enum AccountDeletionConfirmation {
    static func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.touchIDAuthenticationAllowableReuseDuration = 0
        defer { context.invalidate() }
        var error: NSError?
        // Face ID / Touch ID is offered when enrolled; iOS manages device-passcode fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw AccountDeletionError.deviceAuthenticationUnavailable
        }
        do {
            let confirmed = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Confirm that you want to permanently delete your account."
            )
            guard confirmed else { throw CancellationError() }
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel: throw CancellationError()
            default: throw AccountDeletionError.deviceAuthenticationUnavailable
            }
        }
    }
}
