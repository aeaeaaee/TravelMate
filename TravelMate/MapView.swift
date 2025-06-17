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
struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = LocationSearchService()
    
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: IdentifiablePlace?
    @State private var route: MKPolyline? // Holds the calculated route polyline.
    @State private var fromRouteMapItem: MKMapItem? // Holds the 'From' location for route display
    @State private var toRouteMapItem: MKMapItem?   // Holds the 'To' location for route display
    @State private var isLocationSelected = false // Tracks if a location is selected in the main search
    @State private var isInitialLocationSet = false // Tracks if the map has centered on the initial location.
    @State private var isSelectionInProgress = false
    @State private var visibleRegion: MKCoordinateRegion? // Tracks the map's visible region

    // An enum and state property to manage the focus state of the main search bar.
    private enum SearchField: Hashable {
        case main
    }
    @FocusState private var focusedField: SearchField?

    // Enum to represent the different tabs in the navigation bar.
    enum Tab {
        case map, route, journey, settings
    }
    // State variable to track the currently selected tab.
    @State private var selectedTab: Tab = .map

    var body: some View {
        ZStack {
            // The content of the view changes based on the selected tab.
            VStack {
                switch selectedTab {
                case .map:
                    mapView
                case .route:
                    // Pass the closure to handle the route calculation and tab switch.
                    RouteView { fromItem, toItem in
                        self.calculateRoute(from: fromItem, to: toItem)
                        self.selectedTab = .map
                    }
                    .environmentObject(locationManager)
                case .journey:
                    JourneyView()
                case .settings:
                    SettingsView()
                }
            }
            
            // The bottom navigation bar is always visible on top.
            VStack {
                Spacer()
                bottomNavBar
            }
            .ignoresSafeArea() // Allow nav bar to go to the bottom edge
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear the route only when navigating away from map-related views.
            if newValue == .journey || newValue == .settings {
                route = nil
                fromRouteMapItem = nil
                toRouteMapItem = nil
                searchText = "" // Clear MapView's search text
                selectedPlace = nil // Clear MapView's selected place pin
            }
        }
        .onChange(of: locationManager.location) {
            // This modifier watches for the first location update from the locationManager.
            if let userLocation = locationManager.location, !isInitialLocationSet {
                // Center the map on the user's current location.
                let userRegion = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // More zoomed-in span
                )
                withAnimation {
                    position = .region(userRegion)
                }
                // Prevent this from running again.
                isInitialLocationSet = true
            }
        }
    }
    
    // The view content for the "Map" tab.
    private var mapView: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                // Only show selectedPlace pin if no route is active
                if route == nil, let place = selectedPlace {
                    // The Annotation now includes a text label next to the pin.
                    Annotation(place.mapItem.name ?? "Location", coordinate: place.mapItem.placemark.coordinate) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)

                        }
                    }
                }


                // Display the 'From' marker if it exists.
                if let fromItem = fromRouteMapItem {
                    Annotation(fromItem.name ?? "From", coordinate: fromItem.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40)) // Fixed size
                            .foregroundColor(.blue)
                    }
                }

                // Display the 'To' marker if it exists.
                if let toItem = toRouteMapItem {
                    Annotation(toItem.name ?? "To", coordinate: toItem.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40)) // Fixed size
                            .foregroundColor(.red)
                    }
                }
                
                // Display the calculated route if it exists.
                if let route = route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .onTapGesture { focusedField = nil }
            .onMapCameraChange { context in
                visibleRegion = context.region
            }
            .ignoresSafeArea()
            
            VStack {
                LinearGradient(colors: [Color.black.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
            }
            .ignoresSafeArea()

            mainMapInterface
        }
    }
    
    private var mainMapInterface: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                        
                        TextField("Search for a destination", text: $searchText)
                            .foregroundColor(isLocationSelected ? .blue : .primary)
                            .focused($focusedField, equals: .main)
                            .onChange(of: searchText) {
                                if !isSelectionInProgress { isLocationSelected = false }
                                searchService.queryFragment = searchText
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchService.searchResults = []
                                isLocationSelected = false
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 5, y: 3)
                    
                    Button(action: { searchAndRoute(to: searchText) }) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                    }
                    .disabled(searchText.isEmpty || !isLocationSelected)
                }
                .padding(.horizontal).padding(.top)

                if !searchText.isEmpty && !isLocationSelected {
                    VStack(spacing: 0) {
                        ForEach(searchService.searchResults) { result in
                            Button(action: { handleMainSearchSelection(result.completion) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.completion.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(result.completion.subtitle)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(result.distance)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                            .buttonStyle(.plain)
                            
                            if result != searchService.searchResults.last { Divider().padding(.horizontal) }
                        }
                    }
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5, y: 3)
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .onChange(of: locationManager.location) {
                searchService.currentLocation = locationManager.location
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: {
                            if let userLocation = locationManager.location {
                                let userRegion = MKCoordinateRegion(center: userLocation.coordinate, span: position.region?.span ?? MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                                withAnimation { position = .region(userRegion) }
                            }
                        }) {
                            Image(systemName: "location.fill").font(.title2).padding(10).frame(width: 44, height: 44)
                        }.background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 4)
                        
                        VStack(spacing: 0) {
                            Button(action: { zoom(in: true) }) { Image(systemName: "plus").font(.system(size: 20, weight: .medium)).padding(10).frame(width: 44, height: 44) }
                            Divider().frame(width: 28)
                            Button(action: { zoom(in: false) }) { Image(systemName: "minus").font(.system(size: 20, weight: .medium)).padding(10).frame(width: 44, height: 44) }
                        }.background(.thinMaterial).clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 4)
                    }.padding().padding(.bottom, 35.0)
                }
            }
        }
    }
    
    // The bottom navigation bar view.
    private var bottomNavBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom) {
                navBarButton(icon: "map.fill", text: "Map", tab: .map)
                navBarButton(icon: "tram.fill", text: "Route", tab: .route, size: 22)
                navBarButton(icon: "figure.walk.motion", text: "Journey", tab: .journey, size:22)
                navBarButton(icon: "gear", text: "Settings", tab: .settings)
            }
            .padding(.top, 8.0).padding(.bottom, 18.0).padding(.horizontal, 17)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.thinMaterial)
                    .ignoresSafeArea()
            )
            .clipShape(.rect(topLeadingRadius: 25, topTrailingRadius: 25))
        }
    }

    // Helper function to create a standard navigation bar button.
    private func navBarButton(icon: String, text: String, tab: Tab, size: CGFloat = 24) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: size))
                Text(text)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == tab ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func handleMainSearchSelection(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                if let error = error { print("MKLocalSearch Error: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async {
                self.route = nil            // Clear previous route
                self.fromRouteMapItem = nil // Clear previous 'From' marker
                self.toRouteMapItem = nil   // Clear previous 'To' marker
                self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
                if let coordinate = mapItem.placemark.location?.coordinate {
                    let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    withAnimation { self.position = .region(newRegion) }
                }
                isSelectionInProgress = true
                self.searchText = "\(completion.title), \(completion.subtitle)"
                self.isLocationSelected = true
                self.searchService.searchResults = []
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    isSelectionInProgress = false
                })
            }
        }
    }

    private func searchAndRoute(to query: String) {
        guard let userLocation = locationManager.location else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000)

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let destinationItem = response?.mapItems.first else {
                if let error = error { print("Search failed for query '\(query)': \(error.localizedDescription)") }
                return
            }
            let sourceItem = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
            DispatchQueue.main.async {
                self.selectedPlace = IdentifiablePlace(mapItem: destinationItem)
                self.calculateRoute(from: sourceItem, to: destinationItem)
                isSelectionInProgress = true
                self.searchText = "\(destinationItem.name ?? ""), \(destinationItem.placemark.title ?? "")"
                self.isLocationSelected = true
                self.searchService.searchResults = []
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    isSelectionInProgress = false
                })
            }
        }
    }
    
    private func calculateRoute(from: MKMapItem, to: MKMapItem) {
        self.selectedPlace = nil // Clear single selected place when showing a route
        let request = MKDirections.Request()
        request.source = from
        request.destination = to
        request.transportType = .automobile

        self.fromRouteMapItem = from // Set 'From' marker for display
        self.toRouteMapItem = to     // Set 'To' marker for display

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let routeResponse = response?.routes.first else {
                if let error = error { print("Route calculation error: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async(execute: {
                self.route = routeResponse.polyline // Changed self?.route to self.route
                // Convert the route's bounding box to a region
                var region = MKCoordinateRegion(routeResponse.polyline.boundingMapRect)
                // Zoom out by increasing the span by 40%
                region.span.latitudeDelta *= 1.4
                region.span.longitudeDelta *= 1.4

                withAnimation {
                    self.position = .region(region)
                }
            })
        }
    }
    
    private func zoom(in zoomIn: Bool) {
        guard let currentRegion = visibleRegion else { return }
        let factor = zoomIn ? 0.5 : 2
        let newSpan = MKCoordinateSpan(latitudeDelta: currentRegion.span.latitudeDelta * factor, longitudeDelta: currentRegion.span.longitudeDelta * factor)
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
        withAnimation { position = .region(newRegion) }
    }
}

#Preview {
    MapView()
}
