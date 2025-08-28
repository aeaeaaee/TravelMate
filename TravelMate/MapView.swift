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

 

// A simple class to hold map state that needs to be accessed directly, bypassing SwiftUI's state update cycle.
class MapStateHolder: ObservableObject {
    var currentRegion: MKCoordinateRegion?
}

// Main View for the application
struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = LocationSearchService()
    @StateObject private var routeViewModel = RouteViewModel()
    
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: IdentifiablePlace?

    @State private var selectedMapFeature: MapFeature?
    @State private var mapSelection: MapSelection<MKMapItem>? = nil
    
    // State for the custom top-anchored sheet invoked by the Go button
    @State private var showGoTopSheet: Bool = false
    @State private var goTopSheetDetent: TopSheetDetent = .half
    
    @State private var isLocationSelected = false // Tracks if a location is selected in the main search
    @State private var isInitialLocationSet = false // Tracks if the map has centered on the initial location.
    @State private var isMapReady = false // Tracks if the map has reported its initial state.
    @State private var isSelectionInProgress = false

    // Toggle to show MapLibre transit base map instead of Apple MapKit
    @State private var showTransitBaseMap = false
    @StateObject private var mapStateHolder = MapStateHolder()

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
        .topSheet(isPresented: $showGoTopSheet, currentDetent: $goTopSheetDetent) {
            VStack(alignment: .leading, spacing: 12) {
                // Placeholder content for Go panel
                Text("Sample text")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Divider()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .onChange(of: routeViewModel.selectedRoute) { _, newSelectedRoute in
            handleAppleRouteChange(newSelectedRoute)
        }
        .onChange(of: routeViewModel.selectedTransitRoute) { _, newTransitRoute in
            handleTransitRouteChange(newTransitRoute)
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
            let mapItems: [MKMapItem] = {
                var items: [MKMapItem] = []
                if routeViewModel.routes.isEmpty && routeViewModel.transitRoutes.isEmpty, let place = selectedPlace {
                    items.append(place.mapItem)
                }
                if let from = routeViewModel.fromItem {
                    items.append(from)
                }
                if let to = routeViewModel.toItem {
                    items.append(to)
                }
                return items
            }()
            
            if showTransitBaseMap {
                TransitView()
                    .ignoresSafeArea()
            } else {
                SwiftUIMap(
                    mapItems: mapItems,
                    overlayPolyline: routeViewModel.selectedRoute?.polyline ?? routeViewModel.selectedTransitRoute?.polyline,
                    highlightItem: (showLocationDetailSheet ? nil : selectedPlace?.mapItem),
                    selection: $mapSelection,
                    featureSelection: $selectedMapFeature,
                    position: $position,
                    onSelectionChange: { newSelection in
                        handleMapSelectionChange(newSelection)
                    },
                    onFeatureTap: { feature in
                        guard feature.kind == .pointOfInterest else { return }
                        // Directly present sheet based on feature coordinate and title.
                        let placemark = MKPlacemark(coordinate: feature.coordinate)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = feature.title
                        DispatchQueue.main.async {
                            self.searchText = feature.title ?? ""
                            self.selectedMapFeature = feature
                            self.handleMainSearchSelection(mapItem, from: feature, presentSheet: true)
                        }
                    },
                    onRegionChange: { region in
                        if !self.isSelectionInProgress {
                            self.position = .region(region)
                            self.mapStateHolder.currentRegion = region
                        }

                        if !isMapReady {
                            isMapReady = true
                        }
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
        applyRegion(region)
    }
    
    private func handleTransitRouteChange(_ newTransitRoute: APIServices.TransitRoute?) {
        guard let transit = newTransitRoute else { return }
        selectedPlace = nil
        var region = MKCoordinateRegion(transit.polyline.boundingMapRect)
        region.span.latitudeDelta *= 1.4
        region.span.longitudeDelta *= 1.4
        applyRegion(region)
    }
    
    private func handleMapSelectionChange(_ newSelection: MapKit.MapSelection<MKMapItem>?) {
        guard let selection = newSelection else {
            // When selection is cleared, dismiss the sheet.
            showLocationDetailSheet = false
            selectedMapFeature = nil
            return
        }
        if let item = selection.value {
            DispatchQueue.main.async {
                self.mapSelection = nil  // Remove native POI highlight so only our pin remains
                self.handleMainSearchSelection(item, presentSheet: true)
            }
        } else if let feature = selection.feature, feature.kind == .pointOfInterest {
            // Built-in POI tapped; create synthetic mapItem and open sheet
            let placemark = MKPlacemark(coordinate: feature.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = feature.title
            DispatchQueue.main.async {
                self.selectedMapFeature = feature
                self.searchText = feature.title ?? ""
                self.handleMainSearchSelection(mapItem, from: feature, presentSheet: true)
            }
        }
    }

    /// Centralized handler for any selection (search, POI tap) to update state and UI.
    private func handleMainSearchSelection(_ mapItem: MKMapItem, from feature: MapFeature? = nil, presentSheet: Bool = false) {
        isSelectionInProgress = true

        self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
        self.selectedMapFeature = feature
        // Build a descriptive search text that includes both name and address when available.
        let namePart = mapItem.name ?? ""
        let addressPart = mapItem.placemark.title ?? ""
        var combined = namePart
        if !addressPart.isEmpty {
            if addressPart.hasPrefix(namePart) {
                combined = addressPart // Address already contains the name
            } else if !namePart.isEmpty {
                combined = "\(namePart), \(addressPart)"
            } else {
                combined = addressPart
            }
        }
        self.searchText = combined
        self.isLocationSelected = true
        self.searchService.searchResults = []
        self.dismissKeyboard()

        // Re-centre the map on the selection, preserving the user's current zoom level.
        if let coordinate = mapItem.placemark.location?.coordinate {
            // Determine the span to preserve zoom without using pattern binding in expressions.
            let preservedSpan: MKCoordinateSpan? = mapStateHolder.currentRegion?.span
            
            if let span = preservedSpan {
                let region = MKCoordinateRegion(center: coordinate, span: span)
                applyRegion(region)
            } else {
                // No known span yet – skip recentering to avoid unwanted zoom.
                isSelectionInProgress = false
            }
        }
        
        if presentSheet {
            self.showLocationDetailSheet = true
        }
    }



    private func handleTabChange(_ newTab: MapView.Tab) {
        // Failsafe: always dismiss the location detail sheet when changing tabs.
        showLocationDetailSheet = false
        if newTab == .journey || newTab == .settings {
            routeViewModel.routes = []
            routeViewModel.transitRoutes = []
            routeViewModel.selectedTransitRoute = nil
            routeViewModel.fromItem = nil
            routeViewModel.toItem = nil
            searchText = ""
            selectedPlace = nil
            isLocationSelected = false
        }
    }
    
    private func handleLocationChange(_ location: CLLocation?) {
        guard let userLocation = location, !isInitialLocationSet else { return }
        let userRegion = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        applyRegion(userRegion)
        isInitialLocationSet = true
    }
    
    /// Smoothly centers the map on the provided region while preserving user interaction.
    /// - Parameter region: The target coordinate region.
        private func applyRegion(_ region: MKCoordinateRegion) {
        // Animate to region without altering the user's current zoom preference.
        withAnimation(.easeInOut(duration: 0.3)) {
            position = .region(region)
            mapStateHolder.currentRegion = region // ensure future zoom operations use this center
        }

        // Use a delayed task to reset the flag after the animation has likely completed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSelectionInProgress = false
        }
    }

    // Helper: perform a tight local POI search around a coordinate to retrieve a real MKMapItem matching the title.
    private func searchByName(_ name: String?, near coordinate: CLLocationCoordinate2D, completion: @escaping (MKMapItem?) -> Void) {
        var request = MKLocalSearch.Request()
        request.naturalLanguageQuery = name
        request.region = MKCoordinateRegion(center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002))
        request.resultTypes = .pointOfInterest
        MKLocalSearch(request: request).start { response, _ in
            completion(response?.mapItems.first)
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
                            .autocapitalization(.words)
                            .onChange(of: searchText) {
                                // Only trigger a new search if the user is actively typing in the search field.
                                if focusedField == .main {
                                    isLocationSelected = false
                                    searchService.queryFragment = searchText
                                }
                                
                                // If text is fully cleared, also remove the map pin.
                                if searchText.isEmpty {
                                    selectedPlace = nil
                                    selectedMapFeature = nil
                                    mapSelection = nil
                                    isLocationSelected = false // Ensure state is reset when cleared
                                    showLocationDetailSheet = false // Clear the state
                                }
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
                            // Clear highlighted POI halo only if a feature is currently active
                            if selectedMapFeature != nil {
                                selectedMapFeature = nil
                                mapSelection = nil
                            }

                            if isLocationSelected, let place = selectedPlace {
                                // Use the already-chosen MKMapItem
                                handleMainSearchSelection(place.mapItem, presentSheet: true)
                                self.showLocationDetailSheet = true
                            } else if !searchText.isEmpty {
                                // Convert search text to a full MKMapItem first. Ensure any existing sheet is closed so it will reopen with new data.
                                if showLocationDetailSheet {
                                    showLocationDetailSheet = false
                                }
                                searchAndSelect(for: searchText)
                            } else {
                                alertMessage = "Please select a location from the search results first, or search for a location."
                                showAlertForNoSelection = true
                            }

                            // Dismiss keyboard
                            focusedField = nil
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray) // Consistent icon color
                                .padding(8)
                        }
                        .disabled(searchText.isEmpty && !isLocationSelected) // Keep disabled logic if appropriate
                    }
                    .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5, y: 3)
                    
                    // This is the "Directions/Go" button, separate from the TextField's internal buttons
                    Button(action: { showGoTopSheet = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 36, height: 36)
                            Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(searchText.isEmpty || !isLocationSelected)
                }
                .padding(.horizontal).padding(.top)

                // Search dropdown extracted for faster type-checking
                searchResultsDropdown
                
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
                                let span = mapStateHolder.currentRegion?.span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                let userRegion = MKCoordinateRegion(center: userLocation.coordinate, span: span)
                                applyRegion(userRegion)
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
            HStack(alignment: .bottom, spacing: 0) {
                 navBarButton(icon: "map.fill", text: "Map", tab: .map)
                 Divider().frame(height: 44)
                 navBarButton(icon: "tram.fill", text: "Route", tab: .route, size: 22)
                 Divider().frame(height: 44)
                 navBarButton(icon: "figure.walk.suitcase.rolling", text: "Journey", tab: .journey, size: 22)
                 Divider().frame(height: 44)
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
            // Dismiss the location detail sheet when switching tabs
            if selectedTab != tab {
                showLocationDetailSheet = false
            }
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
    
 

    private func searchAndSelect(for query: String) {
        // 1. Try to find an existing completion whose title exactly matches the query.
        if let exact = searchService.searchResults.first(where: { result in
            let title = (result.resolvedTitle ?? result.completion.title).lowercased()
            return title == query.lowercased()
        }) {
            let req = MKLocalSearch.Request(completion: exact.completion)
            if let region = mapStateHolder.currentRegion {
                req.region = region
            }
            MKLocalSearch(request: req).start { response, _ in
                if let mapItem = response?.mapItems.first {
                    DispatchQueue.main.async {
                        self.handleMainSearchSelection(mapItem, presentSheet: true)
                    }
                }
            }
            return
        }
        // 2. Fallback: plain natural language search.
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = mapStateHolder.currentRegion {
            request.region = region
        }
        request.resultTypes = .pointOfInterest
        MKLocalSearch(request: request).start { response, _ in
            guard let items = response?.mapItems, !items.isEmpty else { return }
            // If we already have a pin on the map, pick the result closest to it.
            let chosen: MKMapItem
            if let anchorLoc = self.selectedPlace?.mapItem.placemark.location {
                chosen = items.min(by: { lhs, rhs in
                    let lhsDist = lhs.placemark.location?.distance(from: anchorLoc) ?? Double.greatestFiniteMagnitude
                    let rhsDist = rhs.placemark.location?.distance(from: anchorLoc) ?? Double.greatestFiniteMagnitude
                    return lhsDist < rhsDist
                }) ?? items[0]
            } else {
                chosen = items[0]
            }
            DispatchQueue.main.async {
                self.handleMainSearchSelection(chosen, presentSheet: true)
            }
        }
    }
    


    // MARK: - Extracted Views
    @ViewBuilder
    private var searchResultsDropdown: some View {
        if !searchText.isEmpty && !isLocationSelected {
            VStack(spacing: 0) {
                ForEach(searchService.searchResults) { result in
                                        Button(action: {
                        let request = MKLocalSearch.Request(completion: result.completion)
                        let search = MKLocalSearch(request: request)
                        search.start { response, error in
                            if let mapItem = response?.mapItems.first {
                                DispatchQueue.main.async {
                                    self.handleMainSearchSelection(mapItem, presentSheet: false)
                                    self.isLocationSelected = true
                                    self.selectedMapFeature = nil
                                }
                            }
                        }
                    }) {
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
    }

    private func zoom(in zoomIn: Bool) {
        guard let currentRegion = mapStateHolder.currentRegion else { return }
        let factor = zoomIn ? 0.5 : 2
        let newSpan = MKCoordinateSpan(latitudeDelta: currentRegion.span.latitudeDelta * factor, longitudeDelta: currentRegion.span.longitudeDelta * factor)
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
        applyRegion(newRegion)
    }
}

#Preview {
    MapView()
}

#if DEBUG
struct TopSheetSizing_Previews: PreviewProvider {
    struct Demo: View {
        @State private var showTopSheet: Bool = true
        @State private var detent: TopSheetDetent = .half

        var body: some View {
            MapView()
                .topSheet(isPresented: $showTopSheet, currentDetent: $detent) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Placeholder just under the dynamic island / status bar
                        Text("Sample text")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Divider()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
        }
    }

    static var previews: some View {
        Demo()
            .previewDisplayName("Top Sheet")
    }
}
struct BottomSheetSizing_Previews: PreviewProvider {
    struct Demo: View {
        @State private var showBottomSheet: Bool = true
        @State private var detent: Detent = .half
        @State private var previewSelectedTab: MapView.Tab = .map

        @State private var appleParkItem: MKMapItem? = nil

        private func fetchApplePark() {
            var request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "Apple Park Visitor Center"
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            MKLocalSearch(request: request).start { response, _ in
                if let found = response?.mapItems.first {
                    DispatchQueue.main.async { self.appleParkItem = found }
                }
            }
        }

        var body: some View {
            MapView()
                .onAppear { fetchApplePark() }
                .bottomSheet(isPresented: $showBottomSheet, currentDetent: $detent) {
                    Group {
                        if let item = appleParkItem {
                            LocationView(selectedTab: $previewSelectedTab, mapItem: item, mapFeature: nil)
                                .environmentObject(RouteViewModel())
                        } else {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("Loading Apple Park…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                        }
                    }
                }
        }
    }

    static var previews: some View {
        Demo()
            .previewDisplayName("Bottom Sheet")
    }
}

#endif
