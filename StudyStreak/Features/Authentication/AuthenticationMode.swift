enum AuthenticationMode: Hashable {
    case signUp
    case signIn

    var title: String {
        switch self {
        case .signUp: "Start your\nstudy streak."
        case .signIn: "Welcome back.\nFind your focus."
        }
    }

    var message: String {
        switch self {
        case .signUp: "Keep your sessions, streaks, and friends\nin one quiet place."
        case .signIn: "Pick up where you left off."
        }
    }

    var buttonTitle: String {
        switch self {
        case .signUp: "Create Account"
        case .signIn: "Sign In"
        }
    }

    var passwordPlaceholder: String {
        switch self {
        case .signUp: "Create a password"
        case .signIn: "Enter your password"
        }
    }

    var switchMessage: String {
        switch self {
        case .signUp: "Already have an account?"
        case .signIn: "New to StudyStreak?"
        }
    }

    var switchTitle: String {
        switch self {
        case .signUp: "Sign In"
        case .signIn: "Sign Up"
        }
    }

    var other: Self { self == .signUp ? .signIn : .signUp }
}
