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
    @StateObject private var locationManager = LocationManager()
    @StateObject private var searchService = LocationSearchService()
    
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    @State private var selectedPlace: IdentifiablePlace?
    @State private var route: MKPolyline?
    @State private var isShowingRoutePlanner = false
    @State private var isLocationSelected = false

    // Enum to represent the different tabs in the navigation bar.
    enum Tab {
        case map, route, journey, settings
    }
    // State variable to track the currently selected tab.
    @State private var selectedTab: Tab = .map

    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()
                if let place = selectedPlace {
                    Annotation(place.mapItem.name ?? "Location", coordinate: place.mapItem.placemark.coordinate) {
                        Image(systemName: "mappin")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }
                }
                if let route = route {
                    MapPolyline(route)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .ignoresSafeArea()
            
            VStack {
                LinearGradient(colors: [Color.black.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer()
            }
            .ignoresSafeArea()

            mainInterface
        }
        .sheet(isPresented: $isShowingRoutePlanner) {
            RoutePlannerView(
                isShowing: $isShowingRoutePlanner,
                onGetDirections: { from, to in
                    calculateRoute(from: from, to: to)
                },
                userLocation: locationManager.location
            )
            .presentationDetents([.fraction(0.75)])
        }
    }
    
    private var mainInterface: some View {
        ZStack {
            VStack(spacing: 0) {
                // The search bar and route button are now in a horizontal stack.
                HStack {
                    // This VStack will contain the search bar and the results list.
                    VStack(spacing: 4) {
                        //<--START-->
                        // This HStack contains the search bar elements.
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                            
                            // We use a ZStack to toggle between a single-line TextField for input
                            // and a multi-line Text view for displaying the selected location.
                            ZStack(alignment: .leading) {
                                if isLocationSelected {
                                    Text(searchText)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    TextField("Search for a destination", text: $searchText)
                                        .onChange(of: searchText) {
                                            isLocationSelected = false
                                            searchService.queryFragment = searchText
                                        }
                                }
                            }

                            // The clear button still appears inside the text field.
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
                        
                        // The search results list.
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
                        }
                        //<--END-->
                    }
                    
                    // The "Route to location" button is now outside the search bar.
                    Button(action: { searchAndRoute(to: searchText) }) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 32)) // Larger icon for better tap target
                            .foregroundColor(.accentColor)
                    }
                    .disabled(searchText.isEmpty || !isLocationSelected) // Disabled unless a location is selected
                }
                .padding(.horizontal).padding(.top)

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
            
            VStack(spacing: 0) {
                Spacer()
                Divider()
                HStack(alignment: .bottom) {
                    navBarButton(icon: "figure.walk.motion", text: "Journey", tab: .journey, size:22)
                    navBarButton(icon: "map.fill", text: "Map", tab: .map)
                    navBarButton(icon: "tram.fill", text: "Route", tab: .route, size: 22)
                    navBarButton(icon: "gear", text: "Settings", tab: .settings)
                }
                .padding(.top, 8.0).padding(.bottom, 12.0).padding(.horizontal, 17)
                .frame(maxWidth: .infinity).background(.thinMaterial)
                .clipShape(.rect(topLeadingRadius: 25, topTrailingRadius: 25))
            }.ignoresSafeArea()
        }
    }
    
    private func navBarButton(icon: String, text: String, tab: Tab, size: CGFloat = 24) -> some View {
        Button(action: {
            selectedTab = tab
            if tab == .route {
                isShowingRoutePlanner = true
            }
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
                self.route = nil
                self.selectedPlace = IdentifiablePlace(mapItem: mapItem)
                if let coordinate = mapItem.placemark.location?.coordinate {
                    let newRegion = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    withAnimation { self.position = .region(newRegion) }
                }
                
                self.searchText = "\(completion.title), \(completion.subtitle)"
                self.isLocationSelected = true
                self.searchService.searchResults = []
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
                
                self.searchText = "\(destinationItem.name ?? ""), \(destinationItem.placemark.title ?? "")"
                self.isLocationSelected = true
                self.searchService.searchResults = []
            }
        }
    }
    
    private func calculateRoute(from: MKMapItem, to: MKMapItem) {
        let request = MKDirections.Request()
        request.source = from
        request.destination = to
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let routeResponse = response?.routes.first else {
                if let error = error { print("Route calculation error: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async {
                self.route = routeResponse.polyline
                let rect = routeResponse.polyline.boundingMapRect.insetBy(dx: -500, dy: -500)
                let region = MKCoordinateRegion(rect)
                withAnimation { self.position = .region(region) }
            }
        }
    }
    
    private func zoom(in zoomIn: Bool) {
        guard let currentRegion = position.region else { return }
        let factor = zoomIn ? 0.5 : 2
        let newSpan = MKCoordinateSpan(latitudeDelta: currentRegion.span.latitudeDelta * factor, longitudeDelta: currentRegion.span.longitudeDelta * factor)
        let newRegion = MKCoordinateRegion(center: currentRegion.center, span: newSpan)
        withAnimation { position = .region(newRegion) }
    }
}

#Preview {
    ContentView()
}
