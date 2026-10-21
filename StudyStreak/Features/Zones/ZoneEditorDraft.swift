import CoreLocation
import Foundation
import SwiftUI

// Transient editor state. SwiftData storage is introduced in the next milestone.
struct ZoneEditorDraft {
    var name = ""
    // Initial map center, not the user's current location.
    var coordinate = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
    var radius: CLLocationDistance = 150
    var icon: ZoneIcon = .library
    var customSymbol = "book"
    var subject: ZoneSubjectOption = .mathematics

    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum ZoneIcon: String, CaseIterable, Identifiable {
    case library, desk, cafe, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .library: "Library"
        case .desk: "Desk"
        case .cafe: "Café"
        case .custom: "Custom icon"
        }
    }
    var assetName: String {
        switch self {
        case .library: "ZoneLibrary"
        case .desk: "ZoneDesk"
        case .cafe: "ZoneCafe"
        case .custom: "ZoneAdd"
        }
    }
}

// Preview choices until saved subjects are available from SwiftData.
enum ZoneSubjectOption: String, CaseIterable, Identifiable {
    case mathematics = "Mathematics"
    case physics = "Physics"
    case computerScience = "Computer Science"

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .mathematics: AppColors.Subject.blue
        case .physics: AppColors.Subject.purple
        case .computerScience: AppColors.Subject.teal
        }
    }
}
