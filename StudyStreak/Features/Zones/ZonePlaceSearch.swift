import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class ZonePlaceSearch: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    var query = ""
    private(set) var suggestions: [Suggestion] = []
    private(set) var results: [Result] = []
    private(set) var isSearching = false
    private(set) var message: String?
    @ObservationIgnored private var activeSearch: MKLocalSearch?
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var completer: MKLocalSearchCompleter?

    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion
    }

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
    }

    func suggest(near region: MKCoordinateRegion) {
        clearResults()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else { return }
        let completer = MKLocalSearchCompleter()
        completer.region = region
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
        self.completer = completer
        isSearching = true
        completer.queryFragment = term
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard self.completer === completer else { return }
        suggestions = completer.results.prefix(8).map {
            Suggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
        }
        isSearching = false
        message = suggestions.isEmpty ? "No suggestions. Press Search to look for this place." : nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard self.completer === completer else { return }
        isSearching = false
        message = "Couldn’t load suggestions. Check your connection or press Search to try again."
    }

    func resolve(_ suggestion: Suggestion, near region: MKCoordinateRegion) async -> Result? {
        clearResults()
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        request.region = region
        guard let found = await perform(request) else { return nil }
        guard let first = found.first else {
            message = "That place couldn’t be located. Try another result or place the pin on the map."
            return nil
        }
        return first
    }

    func search(near region: MKCoordinateRegion) async {
        clearResults()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        if let found = await perform(request) {
            results = found
            message = found.isEmpty ? "No places found. Try a different name or address." : nil
        }
    }

    private func perform(_ request: MKLocalSearch.Request) async -> [Result]? {
        let identifier = requestID
        let search = MKLocalSearch(request: request)
        activeSearch = search
        isSearching = true
        defer {
            if requestID == identifier { isSearching = false; activeSearch = nil }
        }
        do {
            let response = try await search.start()
            guard requestID == identifier, !Task.isCancelled else { return nil }
            return response.mapItems.prefix(8).compactMap { item -> Result? in
                let coordinate = item.placemark.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
                return Result(name: item.name ?? query, address: item.placemark.title ?? "", coordinate: coordinate)
            }
        } catch {
            guard requestID == identifier, !Task.isCancelled else { return nil }
            message = "Couldn’t search for places. Check your connection and try again."
            return nil
        }
    }

    func select(_ result: Result) {
        clearResults()
        query = result.name
    }

    func clear() {
        clearResults()
        query = ""
    }

    func clearResults() {
        cancel()
        suggestions = []
        results = []
        message = nil
    }

    func cancel() {
        requestID = UUID()
        completer?.delegate = nil
        completer?.cancel()
        completer = nil
        activeSearch?.cancel()
        activeSearch = nil
        isSearching = false
    }
}
