import Foundation
import MapKit
import Combine
import CoreLocation

// A custom struct to hold a search completion and its calculated distance.
// Unchecked Sendable is safe because it's a value type (struct) with Sendable properties.
struct SearchResult: Identifiable, Hashable, @unchecked Sendable {
    let id = UUID()
    let completion: MKLocalSearchCompletion
    var distance: String = "" // e.g., "2.5 km away"
    // Resolved values retrieved via MKLocalSearch for richer display
    var resolvedTitle: String? = nil
    var resolvedSubtitle: String? = nil
}

// MKLocalSearchCompletion is value semantic and thread-safe; mark as unchecked Sendable for use in @Sendable closures.
extension MKLocalSearchCompletion: @unchecked Sendable {}
// MKMapItem is used only for value extraction inside Sendable closures; mark as unchecked Sendable.
extension MKMapItem: @unchecked Sendable {}


// An actor to safely collect and update search results from multiple concurrent tasks.
private actor SearchResultCollector {
    private var results: [SearchResult]

    init(completions: [MKLocalSearchCompletion]) {
        self.results = completions.map { SearchResult(completion: $0) }
    }

    // Safely updates a result at a specific index.
    func update(at index: Int, distance: String, title: String?, subtitle: String?) {
        guard results.indices.contains(index) else { return }
        results[index].distance = distance
        results[index].resolvedTitle = title
        results[index].resolvedSubtitle = subtitle
    }

    // Returns a copy of the collected results.
    func getResults() -> [SearchResult] {
        return results
    }
}


@MainActor
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
        self.completer.resultTypes = .pointOfInterest
        
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
        nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Remove generic "nearby" suggestions and take up to 8 results for richer list.
        let nonGeneric = completer.results.filter { completion in
            // Filter out items whose subtitle contains "nearby" (e.g., "Search Nearby", "Show nearby")
            !completion.subtitle.lowercased().contains("nearby")
        }
        // If filtering removed everything, fall back to original list.
        let pool = nonGeneric.isEmpty ? completer.results : nonGeneric
        let selectedCompletions = Array(pool.prefix(3))
        
        // Fetch distances and details concurrently in a Task.
        Task { [selectedCompletions] in
            await self.fetchDistances(for: selectedCompletions)
        }
    }
    
    // Fetches coordinates for each completion and calculates the distance using modern concurrency.
    private func fetchDistances(for completions: [MKLocalSearchCompletion]) async {
        guard let userLocation = self.currentLocation else { return }

        let collector = SearchResultCollector(completions: completions)

        await withTaskGroup(of: Void.self) { group in
            for (index, completion) in completions.enumerated() {
                                                group.addTask { @Sendable [userLocation] in
                    let request = MKLocalSearch.Request(completion: completion)
                    
                    // Bridge the callback-based API to async/await.
                    let mapItem: MKMapItem? = await withCheckedContinuation { continuation in
                                                MKLocalSearch(request: request).start { @Sendable response, _ in
                            continuation.resume(returning: response?.mapItems.first)
                        }
                    }

                    if let item = mapItem, let destinationLocation = item.placemark.location {
                        let distanceInMeters = userLocation.distance(from: destinationLocation)
                        let distanceInKm = distanceInMeters / 1000
                        await collector.update(
                            at: index,
                            distance: String(format: "%.1f km", distanceInKm),
                            title: item.name,
                            subtitle: item.placemark.title
                        )
                    }
                }
            }
        }

        let finalResults = await collector.getResults()
        await self.processAndPublish(results: finalResults)
    }
    
    // Sorts, filters, and publishes the final search results on the main thread.
    @MainActor
    private func processAndPublish(results: [SearchResult]) {
        // Sort the results by distance.
        let sortedResults = results.sorted { (lhs, rhs) in
            guard let lhsDistanceStr = lhs.distance.split(separator: " ").first,
                  let lhsDistance = Double(lhsDistanceStr),
                  let rhsDistanceStr = rhs.distance.split(separator: " ").first,
                  let rhsDistance = Double(rhsDistanceStr) else {
                return false
            }
            return lhsDistance < rhsDistance
        }
        
        // Filter out completions that do not have a resolved subtitle.
        let withAddress = sortedResults.filter { result in
            if let subtitle = result.resolvedSubtitle {
                return !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
        
        // Deduplicate based on resolved title + subtitle.
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

    // Fetch Google Places formatted address for each result.
    @MainActor
    private func enrichAddressesWithGoogle() {
        for index in searchResults.indices {
            let title = searchResults[index].resolvedTitle ?? searchResults[index].completion.title
            let subtitle = searchResults[index].resolvedSubtitle ?? searchResults[index].completion.subtitle
            let query = "\(title), \(subtitle)"
            Task {
                if let details = try? await GooglePlacesAPIService.shared.placeDetails(forQuery: query) {
                    // This check is important to avoid out-of-bounds access if searchResults changes.
                    if self.searchResults.indices.contains(index) {
                        self.searchResults[index].resolvedSubtitle = details.address
                    }
                }
            }
        }
    }

    // Delegate method for handling search completer errors.
        nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("MKLocalSearchCompleter Error: \(error.localizedDescription)")
    }
<<<<<<< HEAD

=======
    
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
    // Generates a web search URL for the given query.
    func generateWebSearchURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
<<<<<<< HEAD
        // Using Google search as a common example.
=======
        // Using Google search as a common example. This can be changed to any search engine.
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
        return URL(string: "https://www.google.com/search?q=\(encodedQuery)")
    }
}
