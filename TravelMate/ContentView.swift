import SwiftUI
import MapKit

// Main View for the application
struct ContentView: View {
    // Manages location services and updates.
    @StateObject private var locationManager = LocationManager()
    
    //<--START-->
    // Service to handle location search completions and distance calculation.
    @StateObject private var searchService = LocationSearchService()
    //<--END-->
    
    // Holds the text from the search bar.
    @State private var searchText = ""
    
    // Defines the visible region of the map.
    @State private var region = MKCoordinateRegion(
        // Defaulting to Hong Kong as the initial location.
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        ZStack {
            // Layer 1: The Map background
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()

            //<--START-->
            // Layer 2: The UI elements (Search and Controls)
            VStack(spacing: 0) {
                // A single container for the search bar and its results.
                VStack(spacing: 0) {
                    // The Search Bar UI
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.primary)
                        
                        TextField("Search for a destination", text: $searchText)
                            // When text changes, update the search service's query.
                            .onChange(of: searchText) {
                                searchService.queryFragment = searchText
                            }
                    }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    // The Dropdown List for Search Results, now showing distance.
                    if !searchService.searchResults.isEmpty && !searchText.isEmpty {
                        Divider() // Separator between search bar and results.
                        
                        ForEach(searchService.searchResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.completion.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // A horizontal stack to hold the subtitle and the distance.
                                HStack {
                                    Text(result.completion.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(result.distance)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .contentShape(Rectangle()) // Makes the whole area tappable.
                            .onTapGesture {
                                // Handle the user's selection.
                                handleSelection(result.completion)
                            }
                            
                            // Add a divider unless it's the last item.
                            if result != searchService.searchResults.last {
                                Divider()
                            }
                        }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5, y: 3)
                .padding(.horizontal)
                .padding(.top)

                Spacer()
            }
            .onChange(of: locationManager.location) {
                // Update the search service with the user's current location.
                searchService.currentLocation = locationManager.location
            }
            //<--END-->

            // Layer 3: The Map Controls
            VStack {
                Spacer() // Pushes controls to the bottom
                HStack {
                    Spacer() // Pushes controls to the right
                    
                    VStack(spacing: 12) {
                        // Geolocation Button
                        Button(action: {
                            if let userLocation = locationManager.location {
                                withAnimation {
                                    region.center = userLocation.coordinate
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .padding(10)
                                .frame(width: 44, height: 44)
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)

                        // Combined Zoom In/Out Buttons
                        VStack(spacing: 0) {
                            Button(action: { zoom(in: true) }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .padding(10)
                                    .frame(width: 44, height: 44)
                            }
                            Divider().frame(width: 28)
                            Button(action: { zoom(in: false) }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 20, weight: .medium))
                                    .padding(10)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
    }
    
    //<--START-->
    // Handles tapping on a search result.
    private func handleSelection(_ completion: MKLocalSearchCompletion) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                if let error = error {
                    print("MKLocalSearch Error: \(error.localizedDescription)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.searchText = completion.title
                if let coordinate = mapItem.placemark.location?.coordinate {
                    self.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                }
                // Clear search text and completions to hide the list.
                self.searchText = ""
                self.searchService.searchResults = []
            }
        }
    }
    
    // Refactored zoom logic.
    private func zoom(in zoomIn: Bool) {
        withAnimation {
            let factor = zoomIn ? 0.5 : 2
            region.span.latitudeDelta *= factor
            region.span.longitudeDelta *= factor
        }
    }
    //<--END-->
}

#Preview {
    ContentView()
}
