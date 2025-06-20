import Foundation
import MapKit
import Combine

// ViewModel to contain all the logic for the RoutePlannerView.

// Enum for different transport options, conforming to CaseIterable and Identifiable for Picker use.
enum TransportType: String, CaseIterable, Identifiable {
    case car = "Car"
    case transit = "Public Transit"
    case walking = "Walk"
    
    var id: String { self.rawValue }
    
    var systemImageName: String {
        switch self {
        case .car:
            return "car.fill"
        case .transit:
            return "tram.fill"
        case .walking:
            return "figure.walk"
        }
    }
    
    // Computed property to get the corresponding MapKit transport type.
    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .car:
            return .automobile
        case .transit:
            return .transit
        case .walking:
            return .walking
        }
    }
}

class RouteViewModel: ObservableObject {
    
    // Published properties to hold the state, which the View will observe.
    @Published var fromText = ""
    @Published var toText = ""
    @Published var transportType: TransportType = .car
    
    @Published var fromItem: MKMapItem?
    @Published var toItem: MKMapItem?
    @Published var routes: [MKRoute] = []
    @Published var selectedRoute: MKRoute? = nil
    
    @Published var selectedFromResult: MKLocalSearchCompletion? = nil
    @Published var selectedToResult: MKLocalSearchCompletion? = nil

    // MARK: - Helper Functions

    func formattedTravelTime(time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short // e.g., "1h 10m" or "25m"
        return formatter.string(from: time) ?? ""
    }
    
    // Services for handling search completions for the "From" and "To" fields.
    @Published var fromSearchService = LocationSearchService()
    @Published var toSearchService = LocationSearchService()
    
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Set up subscribers to link text fields to search services.
        $fromText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                guard let self = self else { return }

                let currentSelectedFullText = (self.selectedFromResult?.title ?? "") +
                                              (self.selectedFromResult?.subtitle.isEmpty == false ? ", \(self.selectedFromResult?.subtitle ?? "")" : "")

                if newText == currentSelectedFullText && self.selectedFromResult != nil {
                    // Text matches the selected item, and an item is indeed selected.
                    // This means the text field was populated by a selection.
                    // Do NOT trigger a new search. The dropdown should remain closed.
                    // The searchResults were already cleared in handleResultSelection.
                } else {
                    // User is typing something new, has cleared the field, or the text doesn't match a previous selection.
                    if newText != currentSelectedFullText { // Clear selection if text diverges
                        self.selectedFromResult = nil
                    }
                    self.fromSearchService.queryFragment = newText
                }
            }
            .store(in: &cancellables)
            
        $toText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                guard let self = self else { return }

                let currentSelectedFullText = (self.selectedToResult?.title ?? "") +
                                              (self.selectedToResult?.subtitle.isEmpty == false ? ", \(self.selectedToResult?.subtitle ?? "")" : "")

                if newText == currentSelectedFullText && self.selectedToResult != nil {
                    // Text matches the selected item, and an item is indeed selected.
                    // Do NOT trigger a new search.
                } else {
                    // User is typing something new, has cleared the field, or the text doesn't match a previous selection.
                    if newText != currentSelectedFullText { // Clear selection if text diverges
                        self.selectedToResult = nil
                    }
                    self.toSearchService.queryFragment = newText
                }
            }
            .store(in: &cancellables)
    }
    
    // Fills the "From" field with the user's current location.
    func useCurrentLocation(location: CLLocation?) {
        fromText = "My Location"
        if let location = location {
            fromItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        }
        fromSearchService.searchResults = [] // Clear results
        selectedFromResult = nil // Clear selection when using current location
    }
    
    // Handles the selection of a search result.
    func handleResultSelection(_ completion: MKLocalSearchCompletion, forFromField: Bool) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                if let error = error { print("Search Error: \(error)") }
                return
            }
            // MARK: - Private Methods for Search Logic
            DispatchQueue.main.async {
                let fullText = completion.title + (completion.subtitle.isEmpty ? "" : ", \(completion.subtitle)")
                if forFromField {
                    self.fromText = fullText
                    self.fromItem = mapItem
                    self.selectedFromResult = completion // Store selected completion
                    self.fromSearchService.searchResults = [] // Clear results to hide dropdown
                } else {
                    self.toText = fullText
                    self.toItem = mapItem
                    self.selectedToResult = completion // Store selected completion
                    self.toSearchService.searchResults = [] // Clear results to hide dropdown
                }
            }
        }
    }

    func calculateRoutes(completion: @escaping (Bool) -> Void) {
        self.selectedRoute = nil // Clear previously selected route
        guard let from = fromItem, let to = toItem else {
            completion(false)
            return
        }

        let request = MKDirections.Request()
        request.source = from
        request.destination = to
        request.transportType = self.transportType.mkTransportType
        request.requestsAlternateRoutes = true

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let response = response, !response.routes.isEmpty else {
                if let error = error {
                    print("Route calculation error: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self.routes = []
                    completion(false)
                }
                return
            }

            DispatchQueue.main.async {
                let sortedRoutes = response.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
                self.routes = Array(sortedRoutes.prefix(3))
                completion(true)
            }
        }
    }
}
