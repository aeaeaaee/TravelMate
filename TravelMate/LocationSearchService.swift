import Foundation
import MapKit
import Combine
import CoreLocation

// A custom struct to hold a search completion and its calculated distance.
struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var distance: String = "" // e.g., "2.5 km away"
    // Resolved values retrieved via MKLocalSearch for richer display
    var resolvedTitle: String? = nil
    var resolvedSubtitle: String? = nil
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
        // Remove generic "nearby" suggestions and take up to 8 results for richer list.
        let nonGeneric = completer.results.filter { completion in
            // Filter out items whose subtitle contains "nearby" (e.g., "Search Nearby", "Show nearby")
            !completion.subtitle.lowercased().contains("nearby")
        }
        // If filtering removed everything, fall back to original list.
        let pool = nonGeneric.isEmpty ? completer.results : nonGeneric
        let selectedCompletions = Array(pool.prefix(3))
        self.fetchDistances(for: selectedCompletions)
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
                    
                    // Update distance
                    let distanceInMeters = userLocation.distance(from: destinationLocation)
                    let distanceInKm = distanceInMeters / 1000
                    resultsWithDistance[i].distance = String(format: "%.1f km", distanceInKm)
                    // Store resolved title/subtitle for richer UI display
                    resultsWithDistance[i].resolvedTitle = mapItem.name
                    resultsWithDistance[i].resolvedSubtitle = mapItem.placemark.title
                }
            }
        }
        
        // When all searches are complete, sort the results and update the UI.
        group.notify(queue: .main) {
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
            // Filter out completions that do not have a resolved subtitle (i.e. no meaningful address)
            let withAddress = sortedResults.filter { result in
                if let subtitle = result.resolvedSubtitle {
                    return !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return false
            }
            // Deduplicate based on resolved title + subtitle (case-insensitive).
            let sourceList = withAddress.isEmpty ? sortedResults : withAddress
            var seenKeys = Set<String>()
            let uniqueResults = sourceList.filter { result in
                let title = (result.resolvedTitle ?? result.completion.title).lowercased()
                let subtitle = (result.resolvedSubtitle ?? result.completion.subtitle).lowercased()
                let key = title + "|" + subtitle
                if seenKeys.contains(key) {
                    return false
                } else {
                    seenKeys.insert(key)
                    return true
                }
            }
            self.searchResults = uniqueResults
            self.enrichAddressesWithGoogle()
        }
    }
    
    // Fetch Google Places formatted address for each result and update subtitle if available
    private func enrichAddressesWithGoogle() {
        for index in searchResults.indices {
            let title = searchResults[index].resolvedTitle ?? searchResults[index].completion.title
            let subtitle = searchResults[index].resolvedSubtitle ?? searchResults[index].completion.subtitle
            let query = "\(title), \(subtitle)"
            Task {
                if let details = try? await GooglePlacesAPIService.shared.placeDetails(forTextQuery: query) {
                    await MainActor.run {
                        self.searchResults[index].resolvedSubtitle = details.address
                    }
                }
            }
        }
    }

    // Delegate method for handling search completer errors.
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("MKLocalSearchCompleter Error: \(error.localizedDescription)")
    }

    // Generates a web search URL for the given query.
    func generateWebSearchURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        // Using Google search as a common example. This can be changed to any search engine.
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)")
    }
}
