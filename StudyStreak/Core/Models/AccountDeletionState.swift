import Foundation

nonisolated enum AccountDeletionMethod: String, CaseIterable, Identifiable {
    case password, google
    var id: String { rawValue }
    var title: String { self == .password ? "Email and password" : "Google" }
}

nonisolated enum AccountDeletionError: LocalizedError {
    case unavailableVerification, deviceAuthenticationUnavailable, cloudCleanup, accountChanged

    var errorDescription: String? {
        switch self {
        case .unavailableVerification: "Please sign in again before deleting your account."
        case .deviceAuthenticationUnavailable:
            "Set up Face ID, Touch ID, or a device passcode to confirm account deletion."
        case .cloudCleanup: "Couldn’t finish removing your account data. Check your connection and try again."
        case .accountChanged: "Your signed-in account changed. Please try again."
        }
    }
}

// A retry marker prevents an interrupted deletion from recreating a new profile on next launch.
@MainActor
enum AccountDeletionState {
    static func isPending(_ userID: String) -> Bool {
        UserDefaults.standard.bool(forKey: "accountDeletion.pending.\(userID)")
    }
    static func begin(_ userID: String) {
        UserDefaults.standard.set(true, forKey: "accountDeletion.pending.\(userID)")
    }
    static func complete(_ userID: String) {
        UserDefaults.standard.removeObject(forKey: "accountDeletion.pending.\(userID)")
    }
}
