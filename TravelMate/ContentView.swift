import SwiftUI
import MapKit
// import CoreLocation // This should be in your LocationManager.swift file

// Main View for the application
struct ContentView: View {
    // Manages location services and updates.
    // This now references the LocationManager class defined in LocationManager.swift
    @StateObject private var locationManager = LocationManager()
    
    // Holds the text from the search bar.
    @State private var searchText = ""
    
    // Defines the visible region of the map.
    @State private var region = MKCoordinateRegion(
        // Defaulting to Hong Kong as the initial location.
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        //NEW - START
        // The main ZStack now layers the map, the new search bar, and the controls.
        // The NavigationStack has been removed for a cleaner, full-map look.
        ZStack {
            // Layer 1: The Map background
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()

            // Layer 2: The Floating Search Bar
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.primary)
                    
                    TextField("Search for a destination", text: $searchText)
                }
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5, y: 3)
                .padding(.horizontal)
                .padding(.top)

                Spacer()
            }

            // Layer 3: The Map Controls
            VStack {
                Spacer() // Pushes controls to the bottom
                HStack {
                    Spacer() // Pushes controls to the right
                    
                    VStack(spacing: 12) {
                        // Geolocation Button: Centers the map on the user's current location.
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
                        .background(.thinMaterial) // Using a semi-transparent material for the background
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)

                        // Combined Zoom In/Out Buttons in a single visual block.
                        VStack(spacing: 0) {
                            // Zoom In Button
                            Button(action: {
                                withAnimation {
                                    region.span.latitudeDelta /= 2
                                    region.span.longitudeDelta /= 2
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .padding(10)
                                    .frame(width: 44, height: 44)
                            }

                            // Visual separator between zoom buttons.
                            Divider().frame(width: 28)

                            // Zoom Out Button
                            Button(action: {
                                withAnimation {
                                    region.span.latitudeDelta *= 2
                                    region.span.longitudeDelta *= 2
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 20, weight: .medium))
                                    .padding(10)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .background(.thinMaterial) // Using a semi-transparent material for the background
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                    }
                    .padding() // Padding for the controls so they don't touch the screen edge.
                }
            }
        }
        //NEW - END
    }
}


#Preview {
    ContentView()
}
