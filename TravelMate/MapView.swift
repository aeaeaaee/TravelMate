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
    @StateObject private var routeViewModel = RouteViewModel()
    
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: IdentifiablePlace?

    @State private var isLocationSelected = false // Tracks if a location is selected in the main search
    @State private var isInitialLocationSet = false // Tracks if the map has centered on the initial location.
    @State private var isSelectionInProgress = false
    @State private var visibleRegion: MKCoordinateRegion? // Tracks the map's visible region

    // State for Location Detail sheet
    @State private var showLocationDetailSheet: Bool = false
    @State private var sheetDetent: Detent = .half // Default detent

    // State for alert when trying to view details without a selection
    @State private var showAlertForNoSelection: Bool = false
    @State private var alertMessage: String = ""

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
                    RouteView(viewModel: routeViewModel) {
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
        .alert("Invalid Search", isPresented: $showAlertForNoSelection) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .bottomSheet(isPresented: $showLocationDetailSheet, currentDetent: $sheetDetent, onDismiss: {
            // Don't clear selectedPlace to cache the last selection.
            // Reset detent to default for next presentation.
            sheetDetent = .half
        }) {
            if let place = selectedPlace {
                LocationView(selectedTab: $selectedTab, mapItem: place.mapItem)
                    .environmentObject(routeViewModel)
            } else {
                // Fallback content if selectedPlace is somehow nil when sheet is shown
                Text("No location details available.")
                    .padding()
            }
        }
        .onChange(of: routeViewModel.selectedRoute) { _, newSelectedRoute in
            if let route = newSelectedRoute {
                self.selectedPlace = nil // Clear single place pin if a route is selected
                
                // Create a bounding box for the selected route
                let boundingRect = route.polyline.boundingMapRect
                
                // Convert the bounding box to a region and zoom out slightly
                var region = MKCoordinateRegion(boundingRect)
                region.span.latitudeDelta *= 1.4 // Zoom out a bit to give some padding
                region.span.longitudeDelta *= 1.4
                
                withAnimation {
                    self.position = .region(region)
                }
            } else {
                // Optional: Handle camera when selectedRoute becomes nil (e.g., zoom to user or default)
                // For now, we do nothing, map stays as is or follows user location if no route selected.
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Clear the route only when navigating away from map-related views.
            if newValue == .journey || newValue == .settings {
                routeViewModel.routes = []
                routeViewModel.fromItem = nil
                routeViewModel.toItem = nil
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
                
                // Show single selected place only if no routes are active.
                if routeViewModel.routes.isEmpty, let place = selectedPlace {
                    Annotation(place.mapItem.name ?? "Location", coordinate: place.mapItem.placemark.coordinate) {
                        HStack(spacing: 4) {
                            Text(place.mapItem.name ?? "")
                                .font(.caption).padding(6).background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 2, y: 1)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 40)).foregroundColor(.red)
                        }
                    }
                }

                // Display route markers if routes are available.
                if let fromItem = routeViewModel.fromItem {
                    Annotation(fromItem.name ?? "From", coordinate: fromItem.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40)).foregroundColor(.blue)
                    }
                }

                if let toItem = routeViewModel.toItem {
                    Annotation(toItem.name ?? "To", coordinate: toItem.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40)).foregroundColor(.red)
                    }
                }

                // Display the selected route if available.
                if let selectedRoute = routeViewModel.selectedRoute {
                    MapPolyline(selectedRoute.polyline)
                        .stroke(Color.blue, lineWidth: 5)
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

                        TextField("Search for a destination", text: $searchText)
                            .foregroundColor(isLocationSelected ? .blue : .primary)
                            .focused($focusedField, equals: .main)
                            .onChange(of: searchText) {
                                // If user is typing a new search, reset selection state
                                if !isSelectionInProgress {
                                    isLocationSelected = false
                                }
                                // If text is fully cleared, also remove the map pin
                                if searchText.isEmpty && !isSelectionInProgress {
                                    selectedPlace = nil
                                }
                                searchService.queryFragment = searchText
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchService.searchResults = []
                                isLocationSelected = false
                                focusedField = .main // Keep focus on text field after clearing
                            }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                        }
                        // Info button to show location details
                        Button {
                            if isLocationSelected, selectedPlace != nil {
                                showLocationDetailSheet = true
                                print("Info button tapped for: \(selectedPlace?.mapItem.name ?? "Selected Place")")
                            } else {
                                alertMessage = "Please select a location from the search results first, or search for a location."
                                showAlertForNoSelection = true
                                print("Info button tapped, but no location is selected.")
                            }
                            focusedField = nil // Dismiss keyboard after tapping info button
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray) // Consistent icon color
                                .padding(8)
                        }
                        .disabled(searchText.isEmpty && !isLocationSelected) // Keep disabled logic if appropriate
                    }
                    .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .background(Color(UIColor.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 5, y: 3)
                    
                    // This is the "Directions/Go" button, separate from the TextField's internal buttons
                    Button(action: { searchAndRoute(to: searchText) }) {
                        Image(systemName: "arrow.right.circle.fill")
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
                self.routeViewModel.routes = [] // Clear previous routes
                self.routeViewModel.fromItem = nil // Clear previous 'From' marker data in ViewModel
                self.routeViewModel.toItem = nil   // Clear previous 'To' marker data in ViewModel
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
                // Set items in the shared view model and calculate the route
                self.routeViewModel.fromItem = sourceItem
                self.routeViewModel.toItem = destinationItem
                self.routeViewModel.calculateRoutes { success in
                    // The onChange modifier on routes will handle camera changes.
                    if success {
                        print("Routes found from main search.")
                    } else {
                        print("No routes found from main search.")
                    }
                }
                
                // Update UI
                isSelectionInProgress = true
                self.searchText = "\(destinationItem.name ?? ""), \(destinationItem.placemark.title ?? "")"
                self.isLocationSelected = true
                self.searchService.searchResults = []
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSelectionInProgress = false
                }
            }
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
