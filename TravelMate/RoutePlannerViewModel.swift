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
    
    //<--START-->
    // Handles the selection of a search result.
    // This function now correctly accepts the 'forFromField' argument.
    func handleResultSelection(_ completion: MKLocalSearchCompletion, forFromField: Bool) {
    //<--END-->
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                if let error = error { print("Search Error: \(error)") }
                return
            }
            
            //<--START-->
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
            //<--END-->
        }
    }
}
