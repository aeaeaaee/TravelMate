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
    @State private var selection: MapKit.MapSelection<MKMapItem>?
    @State private var selectedMapFeature: MapFeature?


    @State private var isLocationSelected = false // Tracks if a location is selected in the main search
    @State private var isInitialLocationSet = false // Tracks if the map has centered on the initial location.
    @State private var isSelectionInProgress = false
    // Toggle to show MapLibre transit base map instead of Apple MapKit
    @State private var showTransitBaseMap = false
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
        mainBody
    }
    
    // MARK: - Extracted heavy body to separate property to aid the type checker.
    @ViewBuilder
    private var mainBody: some View {
        AnyView(rootStack)
        .alert("Invalid Search", isPresented: $showAlertForNoSelection) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .bottomSheet(isPresented: $showLocationDetailSheet,
             currentDetent: $sheetDetent,
             onDismiss: { sheetDetent = .half }) {
            locationDetailContent
        }
        .onChange(of: routeViewModel.selectedRoute) { _, newSelectedRoute in
            handleAppleRouteChange(newSelectedRoute)
        }
        .onChange(of: routeViewModel.selectedTransitRoute) { _, newTransitRoute in
            handleTransitRouteChange(newTransitRoute)
        }
        .onChange(of: selection) { _, newSelection in
            handleMapSelectionChange(newSelection)
        }
        .onSubmit(of: .search) {
            searchAndSelect(for: searchText)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(newValue)
        }
        .onChange(of: locationManager.location) { _, newLocation in
            handleLocationChange(newLocation)
        }
        }
    
    // The view content for the "Map" tab.
    private var mapView: some View {
        ZStack {
            // Compute pins / markers to show on the map
            let annotations: [CustomPointAnnotation] = {
                var points: [CustomPointAnnotation] = []
                if routeViewModel.routes.isEmpty && routeViewModel.transitRoutes.isEmpty, let place = selectedPlace {
                    points.append(CustomPointAnnotation(mapItem: place.mapItem))
                }
                if let from = routeViewModel.fromItem {
                    points.append(CustomPointAnnotation(mapItem: from))
                }
                if let to = routeViewModel.toItem {
                    points.append(CustomPointAnnotation(mapItem: to))
                }
                return points
            }()
            // SwiftUIMap expects an array of MKMapItem
            let mapItems: [MKMapItem] = annotations.map { $0.mapItem }
            
            if showTransitBaseMap {
                TransitView()
                    .ignoresSafeArea()
            } else {
                SwiftUIMap(
                    mapItems: mapItems,
                    overlayPolyline: routeViewModel.selectedRoute?.polyline ?? routeViewModel.selectedTransitRoute?.polyline,
                    position: $position,
                    selection: $selection,
                    onRegionChange: { region in
                        // Track visible region for zoom buttons and keep the SwiftUI camera binding in sync with user pans.
                        self.visibleRegion = region
                        // Reset binding to .automatic so UIKit no longer follows the old region. This prevents
                        // feedback loops that keep recentering on the previously selected POI.
                        self.position = .automatic
                    }
                )
                .ignoresSafeArea()
            }
            
            VStack {
                LinearGradient(colors: [Color.black.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            mainMapInterface
        }
        // Dismiss keyboard and disable editing when tapping anywhere outside the search field.
        .simultaneousGesture(TapGesture().onEnded {
            // Dismiss keyboard when tapping outside.
            self.focusedField = nil
        })
    } // End of mainBody
    
    // MARK: - Helpers and subviews

    private func dismissKeyboard() {
        focusedField = nil
    }

    // Existing helper views continue below...
    
    // MARK: - onChange Handlers
    
    private func handleAppleRouteChange(_ newRoute: MKRoute?) {
        guard let route = newRoute else { return }
        selectedPlace = nil
        var region = MKCoordinateRegion(route.polyline.boundingMapRect)
        region.span.latitudeDelta *= 1.4
        region.span.longitudeDelta *= 1.4
        withAnimation { position = .region(region) }
    }
    
    private func handleTransitRouteChange(_ newTransitRoute: APIServices.TransitRoute?) {
        guard let transit = newTransitRoute else { return }
        selectedPlace = nil
        var region = MKCoordinateRegion(transit.polyline.boundingMapRect)
        region.span.latitudeDelta *= 1.4
        region.span.longitudeDelta *= 1.4
        withAnimation { position = .region(region) }
    }
    
    private func handleMapSelectionChange(_ newSelection: MapKit.MapSelection<MKMapItem>?) {
        guard let selection = newSelection else {
            // When selection is cleared, dismiss the sheet.
            showLocationDetailSheet = false
            selectedMapFeature = nil
            return
        }

        // If the user selected a built-in POI, we get a MapFeature.
        if let feature = selection.feature {
            // Ensure we only respond to taps on actual points of interest.
            guard feature.kind == .pointOfInterest else { return }
            // A POI on the map was selected. Create a precise MKMapItem.
            let placemark = MKPlacemark(coordinate: feature.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = feature.title
            showDetails(for: mapItem, from: feature)
            
            // Update UI to reflect the selection.
            searchText = feature.title ?? ""
            isLocationSelected = true
            searchService.searchResults = []
            dismissKeyboard()
        }
    }

    /// Shows the location detail sheet for a selected MKMapItem.
    private func showDetails(for mapItem: MKMapItem, from feature: MapFeature? = nil) {
        // If the call came from a POI tap, verify the coordinates match for safety.
        if let feature = feature {
            guard
                mapItem.placemark.coordinate.latitude == feature.coordinate.latitude,
                mapItem.placemark.coordinate.longitude == feature.coordinate.longitude
            else {
                // This should not happen in normal flow, but it's a critical safety check.
                print("Error: Coordinate mismatch between the tapped MapFeature and the resulting MKMapItem.")
                return
            }
        }
        
        // Ensure the item is valid before showing the sheet.
        guard mapItem.placemark.name != nil else { return }

        selectedPlace = IdentifiablePlace(mapItem: mapItem)
        self.selectedMapFeature = feature
        showLocationDetailSheet = true
        isLocationSelected = true
        
        // Recenter the map on the selection, preserving the current zoom level.
        let span = visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: mapItem.placemark.coordinate, span: span)
        withAnimation { position = .region(region) }
    }


    
    private func handleTabChange(_ newTab: MapView.Tab) {
        if newTab == .journey || newTab == .settings {
            routeViewModel.routes = []
            routeViewModel.transitRoutes = []
            routeViewModel.selectedTransitRoute = nil
            routeViewModel.fromItem = nil
            routeViewModel.toItem = nil
            searchText = ""
            selectedPlace = nil
        }
    }
    
    private func handleLocationChange(_ location: CLLocation?) {
        guard let userLocation = location, !isInitialLocationSet else { return }
        let userRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        withAnimation { position = .region(userRegion) }
        isInitialLocationSet = true
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
                                
                            } else {
                                alertMessage = "Please select a location from the search results first, or search for a location."
                                showAlertForNoSelection = true
                                
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
                    Button(action: { searchAndSelect(for: searchText) }) {
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
                                        Text(result.resolvedTitle ?? result.completion.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(result.resolvedSubtitle ?? result.completion.subtitle)
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
                        // Transit map toggle button (above geolocation)
                        Button(action: { showTransitBaseMap.toggle() }) {
                            Image(systemName: showTransitBaseMap ? "mappin.and.ellipse" : "tram.fill.tunnel")
                                .font(.system(size: 20, weight: .medium))
                                .padding(10)
                                .frame(width: 44, height: 44)
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)

                        Button(action: {
                            if let userLocation = locationManager.location {
                                let span = visibleRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                let userRegion = MKCoordinateRegion(center: userLocation.coordinate, span: span)
                                withAnimation { position = .region(userRegion) }
                            }
                        }) {
                            Image(systemName: "location.fill").font(.title2).padding(10).frame(width: 44, height: 44)
                        }
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                        
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
                    .padding(.bottom, 35.0)
                }
            }
        }
    }
    
    @ViewBuilder
    private var mainTabContent: some View {
        switch selectedTab {
        case .map:
            AnyView(mapView)
        case .route:
            AnyView(RouteView(viewModel: routeViewModel) {
                self.selectedTab = .map
            }
            .environmentObject(locationManager))
        case .journey:
            AnyView(JourneyView())
        case .settings:
            AnyView(SettingsView())
        }
    }
    
    @ViewBuilder
    private var locationDetailContent: some View {
        if let place = selectedPlace {
            LocationView(selectedTab: $selectedTab, mapItem: place.mapItem, mapFeature: selectedMapFeature)
                .environmentObject(routeViewModel)
        } else {
            Text("No location details available.")
                .padding()
        }
    }
    
    @ViewBuilder
    private var rootStack: some View {
        ZStack {
            mainTabContent
            bottomNavOverlay
        }
    }
    
    private var bottomNavOverlay: some View {
        VStack {
            Spacer()
            bottomNavBar
        }
        .ignoresSafeArea()
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
    private func navBarButton(icon: String, text: String, tab: MapView.Tab, size: CGFloat = 24) -> some View {
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
        isSelectionInProgress = true
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSelectionInProgress = false
                if let mapItem = response?.mapItems.first {
                    self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
                    self.selectedMapFeature = nil // Search results don't have a map feature
                    self.searchText = mapItem.name ?? ""
                    self.isLocationSelected = true
                    self.searchService.searchResults = []
                    self.dismissKeyboard()
                    if let coordinate = mapItem.placemark.location?.coordinate {
                        let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        withAnimation { self.position = .region(newRegion) }
                    }
                }
            }
        }
    }

    private func searchAndSelect(for query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = visibleRegion {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if let mapItem = response?.mapItems.first {
                    self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
                    self.selectedMapFeature = nil // Search results don't have a map feature
                    self.searchText = mapItem.name ?? ""
                    self.isLocationSelected = true
                    self.searchService.searchResults = []
                    self.dismissKeyboard()
                    if let coordinate = mapItem.placemark.location?.coordinate {
                        let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        withAnimation { self.position = .region(newRegion) }
                    }
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
