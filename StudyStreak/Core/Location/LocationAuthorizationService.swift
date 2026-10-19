import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class LocationAuthorizationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAccess() {
        guard manager.authorizationStatus == .notDetermined else {
            refresh()
            return
        }

        manager.requestWhenInUseAuthorization()
    }

    func refresh() {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
    }
}
