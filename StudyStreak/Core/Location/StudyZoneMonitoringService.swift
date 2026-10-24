import CoreLocation
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class StudyZoneMonitoringService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isEnabled = true
    private(set) var presence: [UUID: ZonePresence] = [:]
    private(set) var monitoredZoneIDs: Set<UUID> = []
    private(set) var suppressedZoneIDs: Set<UUID> = []
    private(set) var monitoringErrors: [UUID: String] = [:]
    private(set) var capacityLimitedCount = 0
    private(set) var locationServicesAvailable = true
    private(set) var backgroundRefreshAvailable = true
    private(set) var monitoringAvailable = true
    private(set) var preciseLocationAvailable = true
    @ObservationIgnored var onObservation: (@MainActor (UUID, ZonePresence) -> Void)?
    @ObservationIgnored var onUnavailable: (@MainActor (SessionPauseReason) -> Void)?
    @ObservationIgnored private let manager: CLLocationManager
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var ownerID: String?
    @ObservationIgnored private var definitions: [UUID: MonitoredStudyZone] = [:]
    @ObservationIgnored private var queued: [(CLCircularRegion, ZonePresence)] = []
    private let prefix = "StudyStreak.zone."

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var insideZoneIDs: Set<UUID> { Set(presence.filter { $0.value == .inside }.keys) }
    var isReady: Bool {
        isEnabled && authorizationStatus == .authorizedAlways && locationServicesAvailable
            && backgroundRefreshAvailable && monitoringAvailable && preciseLocationAvailable
    }

    var statusMessage: String {
        if !isEnabled { return "Automatic tracking is paused. Manual sessions are always available." }
        if !monitoringAvailable { return "Automatic zones aren’t available on this device." }
        if !locationServicesAvailable { return "Turn on Location Services to use automatic zones." }
        if authorizationStatus == .restricted { return "Location access is restricted on this device." }
        if authorizationStatus != .authorizedAlways {
            return "Allow Always location access so sessions can start and pause while the app is closed."
        }
        if !preciseLocationAvailable { return "Enable Precise Location for your study zones." }
        if !backgroundRefreshAvailable { return "Enable Background App Refresh to receive zone events." }
        if capacityLimitedCount > 0 {
            return "\(monitoredZoneIDs.count) zones are monitored. Pause a zone to make room for another."
        }
        if !monitoringErrors.isEmpty { return "A study zone couldn’t be monitored. Try refreshing." }
        if definitions.isEmpty { return "Enable a zone with an active default subject to begin automatic sessions." }
        return "Sessions start when you arrive and pause when you leave."
    }

    var permissionButtonTitle: String? {
        if !locationServicesAvailable { return "Open Settings" }
        switch authorizationStatus {
        case .notDetermined: return "Allow Location Access"
        case .authorizedWhenInUse:
            return defaults.bool(forKey: "hasRequestedAlwaysLocation") ? "Open Settings" : "Allow Always Access"
        case .denied: return "Open Settings"
        case .authorizedAlways:
            return !preciseLocationAvailable || !backgroundRefreshAvailable ? "Open Settings" : nil
        default: return nil
        }
    }

    func configure(ownerID: String, zones: [MonitoredStudyZone], requestStates: Bool = false) {
        if self.ownerID != ownerID {
            self.ownerID = ownerID
            presence = [:]
            monitoringErrors = [:]
            let key = "automaticZones.enabled.\(ownerID)"
            isEnabled = defaults.object(forKey: key) as? Bool ?? true
            if let data = defaults.data(forKey: "automaticZones.suppressed.\(ownerID)"),
               let saved = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
                suppressedZoneIDs = saved
            } else { suppressedZoneIDs = [] }
        }
        definitions = Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0) })
        suppressedZoneIDs.formIntersection(definitions.keys)
        persistSuppression()
        reconcile(requestStates: requestStates)
        let waiting = queued
        queued.removeAll()
        for (region, state) in waiting { receive(region, state: state) }
    }

    func setEnabled(_ value: Bool) {
        guard let ownerID else { return }
        isEnabled = value
        defaults.set(value, forKey: "automaticZones.enabled.\(ownerID)")
        reconcile(requestStates: true)
    }

    func requestPermission() {
        guard UIApplication.shared.applicationState == .active else { return }
        if !locationServicesAvailable {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            return
        }
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where !defaults.bool(forKey: "hasRequestedAlwaysLocation"):
            defaults.set(true, forKey: "hasRequestedAlwaysLocation")
            manager.requestAlwaysAuthorization()
        case .denied, .authorizedWhenInUse, .authorizedAlways:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        default: break
        }
    }

    func refresh() { reconcile(requestStates: true) }

    func stop() {
        for region in manager.monitoredRegions where region.identifier.hasPrefix(prefix) {
            manager.stopMonitoring(for: region)
        }
        ownerID = nil
        definitions = [:]
        presence = [:]
        monitoredZoneIDs = []
        suppressedZoneIDs = []
        monitoringErrors = [:]
        queued.removeAll()
    }

    func suppressUntilExit(_ ids: Set<UUID>) {
        suppressedZoneIDs.formUnion(ids.intersection(definitions.keys))
        persistSuppression()
    }

    private func persistSuppression() {
        guard let ownerID, let data = try? JSONEncoder().encode(suppressedZoneIDs) else { return }
        defaults.set(data, forKey: "automaticZones.suppressed.\(ownerID)")
    }

    private func reconcile(requestStates: Bool) {
        authorizationStatus = manager.authorizationStatus
        locationServicesAvailable = CLLocationManager.locationServicesEnabled()
        monitoringAvailable = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
            && manager.maximumRegionMonitoringDistance >= 100
        backgroundRefreshAvailable = UIApplication.shared.backgroundRefreshStatus == .available
        preciseLocationAvailable = manager.accuracyAuthorization == .fullAccuracy
        guard ownerID != nil else { return }
        guard isReady else {
            for region in manager.monitoredRegions where region.identifier.hasPrefix(prefix) {
                manager.stopMonitoring(for: region)
            }
            monitoredZoneIDs = []
            presence = [:]
            onUnavailable?(isEnabled ? .permission : .trackingDisabled)
            return
        }
        let otherCount = manager.monitoredRegions.filter { !$0.identifier.hasPrefix(prefix) }.count
        let capacity = max(0, 20 - otherCount)
        let ordered = definitions.values.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
        let desired = Array(ordered.prefix(capacity))
        let wanted = Dictionary(uniqueKeysWithValues: desired.map { ($0.regionIdentifier, $0) })
        capacityLimitedCount = max(0, ordered.count - desired.count)
        for region in manager.monitoredRegions where region.identifier.hasPrefix(prefix) {
            if let circular = region as? CLCircularRegion,
               let spec = wanted[region.identifier], matches(circular, spec: spec) { continue }
            manager.stopMonitoring(for: region)
        }
        let oldIDs = monitoredZoneIDs
        monitoredZoneIDs = Set(desired.map(\.id))
        for id in oldIDs.subtracting(monitoredZoneIDs) {
            presence.removeValue(forKey: id)
            monitoringErrors.removeValue(forKey: id)
        }
        for spec in desired {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: spec.latitude, longitude: spec.longitude),
                radius: min(spec.radius, manager.maximumRegionMonitoringDistance), identifier: spec.regionIdentifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            let existing = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
                .first { $0.identifier == region.identifier && matches($0, spec: spec) }
            if let existing {
                if requestStates { manager.requestState(for: existing) }
            } else {
                presence[spec.id] = .unknown
                monitoringErrors.removeValue(forKey: spec.id)
                manager.startMonitoring(for: region)
            }
        }
    }

    private func matches(_ region: CLCircularRegion, spec: MonitoredStudyZone) -> Bool {
        abs(region.center.latitude - spec.latitude) < 0.0000001
            && abs(region.center.longitude - spec.longitude) < 0.0000001
            && abs(region.radius - min(spec.radius, manager.maximumRegionMonitoringDistance)) < 0.5
    }

    private func receive(_ region: CLCircularRegion, state: ZonePresence) {
        guard ownerID != nil else {
            if queued.count < 40 { queued.append((region, state)) }
            return
        }
        guard isReady, let spec = definitions.values.first(where: { $0.regionIdentifier == region.identifier }),
              monitoredZoneIDs.contains(spec.id), matches(region, spec: spec) else { return }
        presence[spec.id] = state
        monitoringErrors.removeValue(forKey: spec.id)
        if state == .outside {
            suppressedZoneIDs.remove(spec.id)
            persistSuppression()
        }
        onObservation?(spec.id, state)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        reconcile(requestStates: true)
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        guard let region = region as? CLCircularRegion,
              let spec = definitions.values.first(where: { $0.regionIdentifier == region.identifier }),
              matches(region, spec: spec) else { return }
        manager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let region = region as? CLCircularRegion else { return }
        let presence: ZonePresence = state == .inside ? .inside : state == .outside ? .outside : .unknown
        receive(region, state: presence)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let region = region as? CLCircularRegion { receive(region, state: .inside) }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if let region = region as? CLCircularRegion { receive(region, state: .outside) }
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard region != nil else {
            for id in monitoredZoneIDs {
                monitoringErrors[id] = "Couldn’t monitor this zone."
                presence[id] = .unknown
            }
            onUnavailable?(.permission)
            return
        }
        guard let region = region as? CLCircularRegion,
              let spec = definitions.values.first(where: { $0.regionIdentifier == region.identifier }),
              matches(region, spec: spec) else { return }
        manager.stopMonitoring(for: region)
        monitoredZoneIDs.remove(spec.id)
        monitoringErrors[spec.id] = "Couldn’t monitor this zone."
        presence[spec.id] = .unknown
        onUnavailable?(.zoneUnavailable)
    }
}
