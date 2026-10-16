enum OnboardingPage: Int, CaseIterable, Identifiable {
    case study
    case zones
    case streak

    var id: Self { self }

    var next: Self? {
        Self(rawValue: rawValue + 1)
    }

    var title: String {
        switch self {
        case .study:
            "Study without\nthinking about it"
        case .zones:
            "Your zones start\nsessions for you"
        case .streak:
            "Build a streak,\nstay motivated"
        }
    }

    var message: String {
        switch self {
        case .study:
            "Arrive, settle in, and focus.\nStudyStreak takes care of the timer."
        case .zones:
            "Save your favorite study spots. We’ll track\nyour time when you enter and leave."
        case .streak:
            "A little focus, a little more often.\nKeep your progress close with a widget."
        }
    }

    var imageName: String {
        switch self {
        case .study:
            "OnboardingStudy"
        case .zones:
            "OnboardingZones"
        case .streak:
            "OnboardingStreak"
        }
    }

    var buttonTitle: String {
        self == .streak ? "Get Started" : "Continue"
    }
}
