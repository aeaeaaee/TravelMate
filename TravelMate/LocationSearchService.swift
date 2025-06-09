import Foundation
import MapKit
import Combine
import CoreLocation

// A custom struct to hold a search completion and its calculated distance.
struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var distance: String = "" // e.g., "2.5 km away"
}

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    
    // Published property to hold the enhanced search results with distance.
    @Published var searchResults: [SearchResult] = []
    
    // The object that provides search completions from MapKit.
    private var completer: MKLocalSearchCompleter
    
    // A Combine cancellable to manage the subscription to the search query.
    private var cancellable: AnyCancellable?
    
    // The user's current location, which is required for distance calculation.
    var currentLocation: CLLocation?
    
    // The search query fragment that is updated as the user types.
    @Published var queryFragment: String = ""

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        
        // Subscribe to changes in the queryFragment property.
        cancellable = $queryFragment
            .receive(on: DispatchQueue.main)
            // Debounce to prevent excessive requests while the user is typing.
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { fragment in
                if !fragment.isEmpty {
                    self.completer.queryFragment = fragment
                } else {
                    // Clear results when the search text is empty.
                    self.searchResults = []
                }
            }
    }
    
    // Delegate method called when the completer updates with new results.
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Take the top 3 results and fetch their distances.
        let topCompletions = Array(completer.results.prefix(3))
        self.fetchDistances(for: topCompletions)
    }
    
    // Fetches coordinates for each completion and calculates the distance.
    private func fetchDistances(for completions: [MKLocalSearchCompletion]) {
        guard let userLocation = self.currentLocation else { return }
        
        let group = DispatchGroup()
        var resultsWithDistance = completions.map { SearchResult(completion: $0) }

        for i in 0..<resultsWithDistance.count {
            group.enter()
            let request = MKLocalSearch.Request(completion: completions[i])
            
            MKLocalSearch(request: request).start { response, error in
                defer { group.leave() }
                
                if let mapItem = response?.mapItems.first,
                   let destinationLocation = mapItem.placemark.location {
                    
                    let distanceInMeters = userLocation.distance(from: destinationLocation)
                    let distanceInKm = distanceInMeters / 1000
                    resultsWithDistance[i].distance = String(format: "%.1f km", distanceInKm)
                }
            }
        }
        
        // When all searches are complete, sort the results and update the UI.
        group.notify(queue: .main) {
            //<--START-->
            // Sort the results by distance before publishing.
            let sortedResults = resultsWithDistance.sorted { (lhs, rhs) in
                // Safely extract the numeric part of the distance string for comparison.
                guard let lhsDistanceStr = lhs.distance.split(separator: " ").first,
                      let lhsDistance = Double(lhsDistanceStr),
                      let rhsDistanceStr = rhs.distance.split(separator: " ").first,
                      let rhsDistance = Double(rhsDistanceStr) else {
                    // If a distance can't be parsed, don't change their order.
                    return false
                }
                return lhsDistance < rhsDistance
            }
            self.searchResults = sortedResults
            //<--END-->
        }
    }
    
    // Delegate method for handling search completer errors.
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("MKLocalSearchCompleter Error: \(error.localizedDescription)")
    }
}
