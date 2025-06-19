import SwiftUI
import MapKit

struct LocationView: View {
    @EnvironmentObject var routeViewModel: RouteViewModel
    @Environment(\.openURL) var openURL
    @Binding var selectedTab: MapView.Tab // Use MapView.Tab as confirmed by user
    let mapItem: MKMapItem

    // Helper to get a user-friendly category string
    private var categoryString: String {
        guard let category = mapItem.pointOfInterestCategory else {
            // Fallback for general locations or places without a specific category
            if let areaOfInterest = mapItem.placemark.areasOfInterest?.first {
                return areaOfInterest
            }
            return "Location"
        }
        
        // You can expand this to be more descriptive based on MKPointOfInterestCategory cases
        switch category {
        case .airport: return "Airport"
        case .atm: return "ATM"
        case .bakery: return "Bakery"
        case .bank: return "Bank"
        case .beach: return "Beach"
        case .cafe: return "Cafe"
        case .campground: return "Campground"
        case .carRental: return "Car Rental"
        case .evCharger: return "EV Charger"
        case .fireStation: return "Fire Station"
        case .fitnessCenter: return "Fitness Center"
        case .foodMarket: return "Food Market"
        case .gasStation: return "Gas Station"
        case .hospital: return "Hospital"
        case .hotel: return "Hotel"
        case .laundry: return "Laundry"
        case .library: return "Library"
        case .marina: return "Marina"
        case .movieTheater: return "Movie Theater"
        case .museum: return "Museum"
        case .nationalPark: return "National Park"
        case .nightlife: return "Nightlife"
        case .park: return "Park"
        case .parking: return "Parking"
        case .pharmacy: return "Pharmacy"
        case .police: return "Police"
        case .postOffice: return "Post Office"
        case .publicTransport: return "Public Transport"
        case .restaurant: return "Restaurant"
        case .restroom: return "Restroom"
        case .school: return "School"
        case .stadium: return "Stadium"
        case .store: return "Store"
        case .theater: return "Theater"
        case .university: return "University"
        case .winery: return "Winery"
        case .zoo: return "Zoo"
        default:
            let rawDescription = category.rawValue
            if rawDescription.starts(with: "MKPOICategory") {
                return String(rawDescription.dropFirst("MKPOICategory".count))
            }
            return rawDescription.isEmpty ? "Place" : rawDescription
        }
    }

    private var countryFlag: String? {
        guard let countryCode = mapItem.placemark.isoCountryCode else { return nil }
        // Convert ISO country code to emoji flag
        let base: UInt32 = 127397
        var s = ""
        for v in countryCode.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return s.isEmpty ? nil : s
    }

    private var categoryIconName: String {
        guard let category = mapItem.pointOfInterestCategory else {
            return "mappin.and.ellipse" // A generic location icon
        }
        
        switch category {
        case .airport: return "airplane"
        case .atm: return "creditcard.fill"
        case .bakery: return "birthday.cake.fill"
        case .bank: return "building.columns.fill"
        case .beach: return "beach.umbrella.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .campground: return "tent.fill"
        case .carRental: return "car.fill"
        case .evCharger: return "bolt.car.fill"
        case .fireStation: return "flame.fill"
        case .fitnessCenter: return "figure.run"
        case .foodMarket: return "cart.fill"
        case .gasStation: return "fuelpump.fill"
        case .hospital: return "cross.case.fill"
        case .hotel: return "bed.double.fill"
        case .laundry: return "tshirt.fill"
        case .library: return "books.vertical.fill"
        case .marina: return "sailboat.fill"
        case .movieTheater: return "film.fill"
        case .museum: return "building.columns.fill"
        case .nationalPark: return "tree.fill"
        case .nightlife: return "music.mic"
        case .park: return "leaf.fill"
        case .parking: return "p.circle.fill"
        case .pharmacy: return "pills.fill"
        case .police: return "shield.lefthalf.filled"
        case .postOffice: return "envelope.fill"
        case .publicTransport: return "bus.fill"
        case .restaurant: return "fork.knife"
        case .restroom: return "figure.dress.line.vertical.figure"
        case .school: return "graduationcap.fill"
        case .stadium: return "sportscourt.fill"
        case .store: return "storefront.fill"
        case .theater: return "theatermasks.fill"
        case .university: return "building.columns.fill"
        case .winery: return "wineglass.fill"
        case .zoo: return "tortoise.fill"
        default:
            return "mappin.and.ellipse"
        }
    }

    private var categoryIconBackgroundColor: Color {
        guard let category = mapItem.pointOfInterestCategory else { return .gray }
        switch category {
        case .restaurant, .bakery, .foodMarket: return .orange
        case .park, .nationalPark, .campground, .beach, .zoo: return .green
        case .hotel, .cafe, .winery: return .brown
        case .airport, .publicTransport, .carRental, .gasStation: return .blue
        case .museum, .library, .school, .university, .theater: return .purple
        case .hospital, .pharmacy, .police, .fireStation: return .red
        case .bank, .atm, .store: return .indigo
        case .fitnessCenter, .stadium: return .cyan
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Header with Title, Category, and Add Button
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mapItem.name ?? "Unknown Location")
                        .font(.title2)
                        .fontWeight(.bold)
                    if let flag = countryFlag {
                        Text(flag)
                            .font(.title2) // Match name font size or adjust as preferred
                    }
                    Spacer()
                    Button(action: {
                        // Placeholder action for the "+" button
                        print("Add button tapped for \(mapItem.name ?? "Unknown")")
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(categoryString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Apple-style Category Icon
                    ZStack {
                        Circle()
                            .fill(categoryIconBackgroundColor)
                            .frame(width: 22, height: 22) // Adjusted size to fit subheadline
                        Image(systemName: categoryIconName)
                            .font(.system(size: 12, weight: .medium)) // Adjusted size
                            .foregroundColor(.white)
                    }
                    Spacer() // Add spacer to push icon and text to the left if add button is removed or placed elsewhere
                }
            }

            // Stray '}' removed from here
            Divider()
                .padding(.bottom, 4.0)
            
            HStack(spacing: 16) {
                Button {
                    routeViewModel.toItem = mapItem
                    routeViewModel.toText = mapItem.name ?? ""
                    routeViewModel.fromText = "" // Clear previous from text
                    routeViewModel.fromItem = nil // Clear previous from item
                    routeViewModel.routes = [] // Clear previous routes
                    routeViewModel.selectedRoute = nil // Clear selected route
                    selectedTab = .route // Navigate to the Route tab
                } label: {
                    VStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 25))
                        Text("Directions")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity) // Ensure VStack content uses available width for alignment
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large) // Make button taller
                .tint(.blue)
                .frame(maxWidth: .infinity) // Make button take available width

                // Spacer() // Removed Spacer

                Button {
                    if let url = mapItem.url {
                        openURL(url)
                    }
                } label: {
                    VStack {
                        Image(systemName: "safari")
                            .font(.system(size: 25))
                        Text("Website")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity) // Ensure VStack content uses available width for alignment
                }
                .buttonStyle(.bordered)
                .controlSize(.large) // Make button taller
                .disabled(mapItem.url == nil)
                .tint(mapItem.url == nil ? .gray : .green)
                .frame(maxWidth: .infinity) // Make button take available width
            }
            .padding(.bottom, 8) // Add some padding below the buttons

            VStack(alignment: .leading, spacing: 8) {
                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.body)
                }
                
                if let phone = mapItem.phoneNumber {
                    Text(phone)
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer() // Pushes content to the top
        }
        .padding()
    }
} // Correctly closing LocationView struct

#Preview {
    // Helper struct to manage @State for the preview
    struct LocationView_PreviewWrapper: View {
        @State private var previewSelectedTab: MapView.Tab = .map

        var body: some View {
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 34.011286, longitude: -118.499496), addressDictionary: ["Street": "200 Santa Monica Pier", "City": "Santa Monica", "State": "CA", "ZIP": "90401", "Country": "United States"])
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = "Santa Monica Pier"
            mapItem.pointOfInterestCategory = .park
            mapItem.phoneNumber = "+1 (310) 458-8900"

            return LocationView(selectedTab: $previewSelectedTab, mapItem: mapItem)
                .environmentObject(RouteViewModel())
                .frame(height: 300)
                .background(Color(UIColor.systemBackground))
                .previewLayout(.sizeThatFits)
        }
    }

    return LocationView_PreviewWrapper()
}
