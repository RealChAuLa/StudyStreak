import CoreLocation
import Foundation
import SwiftUI

// Transient zone state; subjects are selected from the user's SwiftData records.
struct ZoneEditorDraft {
    var name = ""
    // Initial map center, not the user's current location.
    var coordinate = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
    var radius: CLLocationDistance = 150
    var iconID = "library"
    var subjectID: UUID?
    var address: String?

    var canSave: Bool { (1...60).contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count) && subjectID != nil }
    var icon: ZoneIcon { ZoneIcon(rawValue: iconID) ?? .custom }

    init() { }

    init(zone: StudyZone) {
        name = zone.name
        coordinate = CLLocationCoordinate2D(latitude: zone.latitude, longitude: zone.longitude)
        radius = zone.radiusMeters
        iconID = zone.iconID
        subjectID = zone.defaultSubject?.id
        address = zone.address
    }
}

enum ZoneIcon: String, CaseIterable, Identifiable {
    case library, desk, cafe, custom
    var id: String { rawValue }
    static let extraSymbols: [(name: String, title: String)] = [
        ("book", "Book"), ("graduationcap", "Graduation cap"),
        ("laptopcomputer", "Laptop"), ("house", "Home"),
        ("pencil", "Pencil"), ("mappin", "Map pin"),
        ("books.vertical", "Reading room"), ("building.2", "Study centre"),
        ("sofa", "Study lounge")
    ]
    static func isSupported(_ id: String) -> Bool {
        if let icon = ZoneIcon(rawValue: id), icon != .custom { return true }
        return extraSymbols.contains { $0.name == id }
    }
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
