import Foundation
import MapKit
import Combine

// ViewModel to contain all the logic for the RoutePlannerView.
class RoutePlannerViewModel: ObservableObject {
    
    // Published properties to hold the state, which the View will observe.
    @Published var fromText = ""
    @Published var toText = ""
    
    @Published var fromItem: MKMapItem?
    @Published var toItem: MKMapItem?
    
    //<--START-->
    // Properties to track if a location has been selected for each field.
    @Published var isFromLocationSelected = false
    @Published var isToLocationSelected = false
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
                //<--START-->
                // Only reset the selection state if the user manually clears the field.
                if newText.isEmpty {
                    self?.isFromLocationSelected = false
                    self?.fromItem = nil // Also clear the selected map item.
                }
                self?.fromSearchService.queryFragment = newText
                //<--END-->
            }
            .store(in: &cancellables)
            
        $toText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] newText in
                //<--START-->
                // Only reset the selection state if the user manually clears the field.
                if newText.isEmpty {
                    self?.isToLocationSelected = false
                    self?.toItem = nil // Also clear the selected map item.
                }
                self?.toSearchService.queryFragment = newText
                //<--END-->
            }
            .store(in: &cancellables)
    }
    
    // Fills the "From" field with the user's current location.
    func useCurrentLocation(location: CLLocation?) {
        fromText = "My Location"
        if let location = location {
            fromItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        }
        isFromLocationSelected = true // Mark as selected
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
                    self.fromText = "\(mapItem.name ?? ""), \(mapItem.placemark.title ?? "")"
                    self.fromItem = mapItem
                    self.isFromLocationSelected = true // Mark as selected
                    self.fromSearchService.searchResults = [] // Clear results
                } else {
                    self.toText = "\(mapItem.name ?? ""), \(mapItem.placemark.title ?? "")"
                    self.toItem = mapItem
                    self.isToLocationSelected = true // Mark as selected
                    self.toSearchService.searchResults = [] // Clear results
                }
            }
        }
    }
    
    // Calculates the route and passes the result back via a completion handler.
    func getDirections(completion: @escaping (MKRoute?) -> Void) {
        guard let fromItem = fromItem, let toItem = toItem else {
            completion(nil)
            return
        }
        
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
                completion(nil)
                return
            }
            completion(route)
        }
    }
}
