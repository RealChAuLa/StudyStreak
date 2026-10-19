enum PermissionPage {
    case location
    case notifications

    var title: String {
        switch self {
        case .location: "Let your places\nstart the timer"
        case .notifications: "A gentle nudge\nto keep going"
        }
    }

    var message: String {
        switch self {
        case .location:
            "Allow location access to recognize your study zones. With Always access, tracking can continue while the app is closed."
        case .notifications:
            "Get a reminder when your streak needs a little attention, and take a break when it’s time."
        }
    }

    var imageName: String {
        switch self {
        case .location: "PermissionLocation"
        case .notifications: "PermissionBell"
        }
    }

    var contextImageName: String {
        switch self {
        case .location: "PermissionLock"
        case .notifications: "PermissionMoon"
        }
    }

    var contextMessage: String {
        switch self {
        case .location:
            "Always access comes with automatic zones.\nYour location is never shared with friends."
        case .notifications:
            "Thoughtful reminders, on your schedule.\nYou can change them anytime."
        }
    }

    var buttonTitle: String {
        switch self {
        case .location: "Allow Location Access"
        case .notifications: "Enable Notifications"
        }
    }
}
