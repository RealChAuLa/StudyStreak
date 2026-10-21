import FirebaseAuth
import Foundation

nonisolated enum AccountError: LocalizedError {
    case notConfigured
    case googleNotConfigured
    case missingGoogleURLScheme
    case missingPresenter
    case invalidGoogleToken
    case signedOut
    case usernameTaken
    case invalidUsername
    case invalidDisplayName
    case incompleteProfile

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Firebase configuration is missing from this build."
        case .googleNotConfigured: "Google sign-in isn’t configured for this build. Check the Firebase configuration file."
        case .missingGoogleURLScheme: "Google sign-in needs its reversed client ID added to this app’s URL Types."
        case .missingPresenter: "Couldn’t open Google sign-in. Please try again."
        case .invalidGoogleToken: "Google couldn’t complete sign-in. Please try again."
        case .signedOut: "Please sign in again to continue."
        case .usernameTaken: "That username was just taken. Please choose another."
        case .invalidUsername: "Use 3–20 letters, numbers, dots or underscores."
        case .invalidDisplayName: "Use a display name with 50 characters or fewer."
        case .incompleteProfile: "Choose a username before continuing."
        }
    }

    static func message(for error: Error) -> String {
        guard (error as NSError).domain == AuthErrors.domain else { return error.localizedDescription }
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return "The email or password is incorrect. Please try again."
        case .invalidEmail: return "Enter a valid email address."
        case .emailAlreadyInUse: return "An account already uses that email. Try signing in instead."
        case .weakPassword: return "Choose a stronger password with at least 8 characters."
        case .networkError: return "Check your internet connection and try again."
        case .tooManyRequests: return "Too many attempts. Please wait a little and try again."
        case .operationNotAllowed: return "This sign-in method isn’t enabled yet."
        case .accountExistsWithDifferentCredential:
            return "This email uses another sign-in method. Sign in with the method you used before."
        case .userDisabled: return "This account has been disabled."
        default: return error.localizedDescription
        }
    }
}
