import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class ZonePlaceSearch {
    var query = ""
    private(set) var results: [Result] = []
    private(set) var isSearching = false
    private(set) var message: String?
    @ObservationIgnored private var activeSearch: MKLocalSearch?
    @ObservationIgnored private var requestID = UUID()

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
    }

    func search(near region: MKCoordinateRegion) async {
        cancel()
        results = []
        message = nil
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        let identifier = requestID
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        activeSearch = search
        isSearching = true
        do {
            let response = try await search.start()
            guard requestID == identifier, !Task.isCancelled else { return }
            results = response.mapItems.prefix(8).map { item in
                Result(name: item.name ?? term, address: item.placemark.title ?? "", coordinate: item.placemark.coordinate)
            }
            message = results.isEmpty ? "No places found. Try a different name or address." : nil
        } catch {
            guard requestID == identifier, !Task.isCancelled else { return }
            message = "Couldn’t search for places. Check your connection and try again."
        }
        if requestID == identifier { isSearching = false; activeSearch = nil }
    }

    func select(_ result: Result) {
        cancel()
        query = result.name
        results = []
        message = nil
    }

    func clear() {
        clearResults()
        query = ""
    }

    func clearResults() {
        cancel()
        results = []
        message = nil
    }

    func cancel() {
        requestID = UUID()
        activeSearch?.cancel()
        activeSearch = nil
        isSearching = false
    }
}
