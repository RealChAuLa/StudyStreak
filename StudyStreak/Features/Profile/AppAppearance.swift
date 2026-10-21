import SwiftUI

nonisolated enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearancePreference"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .system: "Match your device settings"
        case .light: "A bright place to focus"
        case .dark: "Easy on the eyes after hours"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var assetName: String {
        switch self {
        case .system: "AppearanceSystem"
        case .light: "AppearanceLight"
        case .dark: "AppearanceDark"
        }
    }
}
