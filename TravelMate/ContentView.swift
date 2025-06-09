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
    
    // Service to handle location search completions for the main search bar.
    @StateObject private var searchService = LocationSearchService()
    
    // Holds the text from the search bar.
    @State private var searchText = ""
    
    // Defines the map's camera position.
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))

    // Holds the currently selected location to display a pin on the map.
    @State private var selectedPlace: IdentifiablePlace?
    
    // Holds the route polyline to be drawn on the map.
    @State private var route: MKPolyline?
    
    // Controls the visibility of the route planner pop-up.
    @State private var isShowingRoutePlanner = false

    var body: some View {
        ZStack {
            // Layer 1: The Map background
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
            
            // Gradient overlay for better status bar visibility
            VStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.4), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .ignoresSafeArea()
                Spacer()
            }

            // Layer 2: Top Search Bar and Map Controls
            mainInterface
        }
        //<--START-->
        // Modifier to present the route planner sheet.
        .sheet(isPresented: $isShowingRoutePlanner) {
            RoutePlannerView(
                isShowing: $isShowingRoutePlanner,
                onGetDirections: { from, to in
                    calculateRoute(from: from, to: to)
                },
                userLocation: locationManager.location
            )
            // Sets the height of the sheet to be 75% of the screen.
            .presentationDetents([.fraction(0.75)])
        }
        //<--END-->
    }
    
    // The main interface including search, map controls, and bottom bar.
    private var mainInterface: some View {
        ZStack {
            VStack(spacing: 0) {
                // Main Search Bar and Results
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search for a destination", text: $searchText)
                            .onChange(of: searchText) { searchService.queryFragment = searchText }
                    }
                    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    if !searchService.searchResults.isEmpty && !searchText.isEmpty {
                        Divider()
                        ForEach(searchService.searchResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.completion.title).font(.headline)
                                HStack {
                                    Text(result.completion.subtitle).font(.subheadline).foregroundColor(.secondary)
                                    Spacer()
                                    Text(result.distance).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture { handleMainSearchSelection(result.completion) }
                            
                            if result != searchService.searchResults.last { Divider() }
                        }
                    }
                }
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(radius: 5, y: 3)
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
                    }.padding().padding(.bottom, 70)
                }
            }
            
            VStack(spacing: 0) {
                Spacer()
                Divider()
                HStack(alignment: .bottom) {
                    navBarButton(icon: "pencil", text: "Record")
                    Button(action: { isShowingRoutePlanner = true }) {
                        navBarButton(icon: "tram.fill", text: "Route", size: 30)
                    }
                    navBarButton(icon: "map.fill", text: "Map")
                    navBarButton(icon: "calendar", text: "Calendar")
                    navBarButton(icon: "gear", text: "Settings")
                }
                .padding(.top, 12).padding(.bottom, 30).padding(.horizontal, 20)
                .frame(maxWidth: .infinity).background(.thinMaterial).foregroundColor(.black)
                .clipShape(.rect(topLeadingRadius: 25, topTrailingRadius: 25))
            }.ignoresSafeArea()
        }
    }
    
    // Helper function to create a navigation bar button.
    private func navBarButton(icon: String, text: String, size: CGFloat = 34) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: size))
            Text(text).font(.system(size: 15))
        }.frame(maxWidth: .infinity)
    }
    
    // Handles selection from the main search bar.
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
                self.searchText = ""
                self.searchService.searchResults = []
            }
        }
    }

    // Calculates a route from a specific start and end point.
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
    
    // Zooms the map in or out.
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
