import CoreLocation
import Foundation
import SwiftUI

// Transient zone state; subjects are selected from the user's SwiftData records.
struct ZoneEditorDraft {
    var name = ""
    // Initial map center, not the user's current location.
    var coordinate = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
    var radius: CLLocationDistance = 150
    var icon: ZoneIcon = .library
    var customSymbol = "book"
    var subjectID: UUID?

    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && subjectID != nil }
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
