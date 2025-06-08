import SwiftUI
import MapKit

// A helper struct to make our map item identifiable for the Map view.
struct IdentifiablePlace: Identifiable {
    let id: UUID
    let mapItem: MKMapItem
    
    init(mapItem: MKMapItem) {
        self.id = UUID()
        self.mapItem = mapItem
    }
}

// Main View for the application
struct ContentView: View {
    // Manages location services and updates.
    @StateObject private var locationManager = LocationManager()
    
    // Service to handle location search completions and distance calculation.
    @StateObject private var searchService = LocationSearchService()
    
    // Holds the text from the search bar.
    @State private var searchText = ""
    
    // Defines the map's camera position. This is the modern replacement for MKCoordinateRegion.
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        // Defaulting to Hong Kong as the initial location.
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    // Holds the currently selected location to display a pin on the map.
    @State private var selectedPlace: IdentifiablePlace?

    //<--START-->
    // Holds the calculated route to be drawn on the map.
    @State private var route: MKPolyline?
    //<--END-->

    var body: some View {
        ZStack {
            // Layer 1: The Map background, now with a pin and route.
            Map(position: $position) {
                // This adds the blue dot for the user's current location.
                UserAnnotation()
                
                // If a place has been selected, show a larger, custom red marker for it.
                if let place = selectedPlace {
                    Annotation(place.mapItem.name ?? "Location", coordinate: place.mapItem.placemark.coordinate) {
                        Image(systemName: "mappin")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .shadow(radius: 2)
                    }
                }
                
                //<--START-->
                // If a route has been calculated, draw it on the map.
                if let route = route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
                //<--END-->
            }
            .ignoresSafeArea()

            // Layer 2: The UI elements (Search and Controls)
            VStack(spacing: 0) {
                // A single container for the search bar and its results.
                VStack(spacing: 0) {
                    // The Search Bar UI
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.primary)
                        
                        TextField("Search for a destination", text: $searchText)
                            .onChange(of: searchText) {
                                searchService.queryFragment = searchText
                            }
                    }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    // The Dropdown List for Search Results, now showing distance.
                    if !searchService.searchResults.isEmpty && !searchText.isEmpty {
                        Divider()
                        
                        ForEach(searchService.searchResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.completion.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                handleSelection(result.completion)
                            }
                            
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
                searchService.currentLocation = locationManager.location
            }

            // Layer 3: The Map Controls
            VStack {
                Spacer() // Pushes controls to the bottom
                HStack {
                    Spacer() // Pushes controls to the right
                    
                    VStack(spacing: 12) {
                        // Geolocation Button
                        Button(action: {
                            if let userLocation = locationManager.location {
                                let userRegion = MKCoordinateRegion(
                                    center: userLocation.coordinate,
                                    span: position.region?.span ?? MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                )
                                withAnimation {
                                    position = .region(userRegion)
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .padding(10)
                                .frame(width: 44, height: 44)
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)

                        //<--START-->
                        // Route calculation button
                        Button(action: {
                            calculateRoute()
                        }) {
                            Image(systemName: "arrow.swap")
                                .font(.title2)
                                .padding(5)
                                .frame(width: 44, height: 44)
                        }
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                        // The button is disabled if there's no destination or user location.
                        .disabled(selectedPlace == nil || locationManager.location == nil)
                        //<--END-->

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
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
    }
    
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
                //<--START-->
                // Clear any previous route before setting a new destination.
                self.route = nil
                //<--END-->
                
                // Set the selected place to show a pin on the map.
                self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
                
                // When a location is selected, update the camera position.
                if let coordinate = mapItem.placemark.location?.coordinate {
                    let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    withAnimation {
                        self.position = .region(newRegion)
                    }
                }
                
                // Clear search text and completions to hide the list.
                self.searchText = ""
                self.searchService.searchResults = []
            }
        }
    }
    
    //<--START-->
    // Calculates the route between the user's location and the selected destination.
    private func calculateRoute() {
        // Ensure we have both a source and a destination.
        guard let sourceLocation = locationManager.location, let destination = selectedPlace else {
            print("Source or destination is missing.")
            return
        }
        
        // Create a direction request.
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceLocation.coordinate))
        request.destination = destination.mapItem
        request.transportType = .automobile // Can be changed to .walking or .transit

        // Perform the direction calculation.
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let routeResponse = response?.routes.first else {
                if let error = error {
                    print("Route calculation error: \(error.localizedDescription)")
                }
                return
            }
            
            // Update the state with the new route polyline.
            DispatchQueue.main.async {
                self.route = routeResponse.polyline
                
                // Adjust the map to show the entire route.
                let rect = routeResponse.polyline.boundingMapRect
                let region = MKCoordinateRegion(rect)
                withAnimation {
                    self.position = .region(region)
                }
            }
        }
    }
    //<--END-->
    
    // Refactored zoom logic to work with MapCameraPosition.
    private func zoom(in zoomIn: Bool) {
        guard let currentRegion = position.region else { return }
        
        let factor = zoomIn ? 0.5 : 2
        let newSpan = MKCoordinateSpan(
            latitudeDelta: currentRegion.span.latitudeDelta * factor,
            longitudeDelta: currentRegion.span.longitudeDelta * factor
        )
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
        
        withAnimation {
            position = .region(newRegion)
        }
    }
}

#Preview {
    ContentView()
}
