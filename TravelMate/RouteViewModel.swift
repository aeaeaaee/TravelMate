import Foundation
import MapKit
import Combine

// ViewModel to contain all the logic for the RoutePlannerView.
class RouteViewModel: ObservableObject {
    
    // Published properties to hold the state, which the View will observe.
    @Published var fromText = ""
    @Published var toText = ""
    
    @Published var fromItem: MKMapItem?
    @Published var toItem: MKMapItem?
    
    //<--START-->
    // This property will hold the calculated route for the view to observe.
    @Published var route: MKPolyline?
    //<--END-->
    
    // Services for handling search completions for the "From" and "To" fields.
    @Published var fromSearchService = LocationSearchService()
    @Published var toSearchService = LocationSearchService()
    
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Set up subscribers to link text fields to search services.
        $fromText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                self?.fromSearchService.queryFragment = newText
            }
            .store(in: &cancellables)
            
        $toText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                self?.toSearchService.queryFragment = newText
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
            
            // Update the correct field based on the 'forFromField' boolean.
            DispatchQueue.main.async {
                if forFromField {
                    self.fromText = mapItem.name ?? ""
                    self.fromItem = mapItem
                    self.fromSearchService.searchResults = [] // Clear results
                } else {
                    self.toText = mapItem.name ?? ""
                    self.toItem = mapItem
                    self.toSearchService.searchResults = [] // Clear results
                }
            }
        }
    }
    
    //<--START-->
    // Calculates the route and updates the published route property.
    func getDirections() {
        self.route = nil // Clear previous route
        guard let fromItem = fromItem, let toItem = toItem else { return }
        
        let request = MKDirections.Request()
        request.source = fromItem
        request.destination = toItem
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                if let error = error {
                    print("Route calculation error: \(error.localizedDescription)")
                }
                return
            }
            // Update the main route property on the main thread.
            DispatchQueue.main.async {
                self.route = route.polyline
            }
        }
    }
    //<--END-->
}
