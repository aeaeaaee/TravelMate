import SwiftUI
import MapKit

<<<<<<< HEAD
// MKLookAroundSceneRequest is used locally within a @Sendable context; mark as unchecked Sendable for Swift concurrency.
extension MKLookAroundSceneRequest: @unchecked Sendable {}
// MKLookAroundScene is used only for value extraction inside Sendable closures; mark as unchecked Sendable.
extension MKLookAroundScene: @unchecked Sendable {}

struct LocationView: View {
    // State variables for Look Around scene
    @State private var lookAroundScene: MKLookAroundScene? = nil
    @State private var isLookAroundAvailable: Bool = true // Assume available until proven otherwise
=======
struct LocationView: View {
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
    @EnvironmentObject var routeViewModel: RouteViewModel
    @Environment(\.openURL) var openURL
    @Binding var selectedTab: MapView.Tab // Use MapView.Tab as confirmed by user
    let mapItem: MKMapItem
<<<<<<< HEAD
    let mapFeature: MapFeature?
    @State private var isFavorite: Bool = false
    // Google Places photo URL
    @State private var placePhotoURL: URL? = nil
    // Google Places details (name, formatted address, etc.)
    @State private var placeDetails: PlaceDetails? = nil
    // Indicates we waited long enough and still have no place details.
    @State private var photoFetchTimedOut: Bool = false

    /// Determines the most relevant Point of Interest category, prioritizing the tapped map feature.
    private var pointOfInterestCategory: MKPointOfInterestCategory? {
        mapFeature?.pointOfInterestCategory ?? mapItem.pointOfInterestCategory
    }

    // Helper to get a user-friendly category string via centralized utility
    private var categoryString: String {
        let base = POINameAndIcon.POIName(for: pointOfInterestCategory)
        if base == "Place", let aoi = mapItem.placemark.areasOfInterest?.first {
            return aoi
        }
        return base
=======

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
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
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

<<<<<<< HEAD
    /// Provides a localized country name using the placemark's ISO country code for reliable context.
    private var locationContext: String {
        guard let countryCode = mapItem.placemark.isoCountryCode else { return "" }
        return Locale.current.localizedString(forRegionCode: countryCode) ?? ""
    }

    /// Combines category and location context for a clean, readable subtitle.
    private var subtitleString: String {
        let context = locationContext
        var subtitleItems: [String] = []
        if !categoryString.isEmpty {
            subtitleItems.append(categoryString)
        }
        if !context.isEmpty {
            subtitleItems.append(context)
        }
        return subtitleItems.joined(separator: " • ")
    }

    // SF Symbol name for the category glyph
    private var categoryIconName: String {
        POINameAndIcon.POIIconName(for: pointOfInterestCategory)
    }

    // Background circle color for the category glyph
    private var categoryIconBackgroundColor: Color {
        POINameAndIcon.POIIconBackgroundColor(for: pointOfInterestCategory)
    }

    // Function to fetch the Look Around scene

    private func fetchLookAroundScene(for coordinate: CLLocationCoordinate2D) async {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        do {
            if let scene = try await request.scene {
                await MainActor.run {
                    self.lookAroundScene = scene
                    self.isLookAroundAvailable = true
                }
            } else {
                await MainActor.run {
                    self.lookAroundScene = nil
                    self.isLookAroundAvailable = false
                }
                print("Look Around scene not available for this location.")
            }
        } catch {
            await MainActor.run {
                self.lookAroundScene = nil
                self.isLookAroundAvailable = false
            }
            print("Failed to fetch Look Around scene: \(error.localizedDescription)")
=======
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
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
<<<<<<< HEAD
            // Display an image for the location, trying MapKit's image first, then Google's.
            if mapFeature?.image != nil || placePhotoURL != nil {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = mapFeature?.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else if let url = placePhotoURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                        case .empty:
                                    Color(.systemGray5).overlay(ProgressView())
                        case .success(let image):
                                    image.resizable().scaledToFill()
                        case .failure:
                                    Color(.systemGray5).overlay(Text("Image failed to load."))
                                @unknown default:
                                    Color(.systemGray5)
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)

                    // Google Images overlay button
                    Button(action: {
                        let name = mapFeature?.title ?? mapItem.name ?? ""
                        let context = locationContext
                        let fullQuery = [name, context].filter { !$0.isEmpty }.joined(separator: ", ")
                        
                        let queryString = fullQuery.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let imgURL = URL(string: "https://www.google.com/search?tbm=isch&q=\(queryString)"), !queryString.isEmpty {
                            openURL(imgURL)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                            Text("Image Search")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(8)
                }
                .frame(height: 200)
                .padding(.bottom, 10)
            } else {
                // Placeholder for when no image is available or is still loading.
                Color(.systemGray5)
                    .frame(height: 200)
                    .padding(.bottom, 10)
                    .overlay(
                        // Show a progress view while waiting for the fetch, otherwise show failure icon.
                        Group {
                            if placeDetails == nil && !photoFetchTimedOut {
                                ProgressView()
                            } else {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
            }

            // Header with Title, Category, and Add Button
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    // Name, flag, and category stacked vertically
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(mapFeature?.title ?? mapItem.name ?? "Unknown Location")
                                .font(.title2)
                                .fontWeight(.bold)
                            if let flag = countryFlag {
                                Text(flag)
                                    .font(.title2)
                            }
                        }
                        HStack {
                            if !subtitleString.isEmpty {
                                Text(subtitleString)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // Apple-style Category Icon, using the specific feature's icon if available.
                            ZStack {
                                Circle()
                                    .fill(mapFeature?.backgroundColor ?? categoryIconBackgroundColor)
                                    .frame(width: 22, height: 22)
                                if let featureIcon = mapFeature?.image {
                                    featureIcon
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: categoryIconName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 1.5)
                            )
                        }
                    }

                    Spacer()

                    // Favorite toggle button
                    Button(action: {
                        isFavorite.toggle()
                    }) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 22))
                            .foregroundColor(isFavorite ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Stray '}' removed from here
=======
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
            
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
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
<<<<<<< HEAD

                // Google Images search button (moved to photo overlay)

=======
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
            }
            .padding(.bottom, 8) // Add some padding below the buttons

            VStack(alignment: .leading, spacing: 8) {
<<<<<<< HEAD
                if let address = placeDetails?.address ?? mapItem.placemark.title {
=======
                if let address = mapItem.placemark.title {
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
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
<<<<<<< HEAD
        .task(id: mapItem) {

            // Debug print for the point of interest category
            print("LocationView: Displaying details for \(mapFeature?.title ?? mapItem.name ?? "Unknown"). Category: \(pointOfInterestCategory?.rawValue ?? "None")")

            // Fetch Google Places photo when selected location changes
            placePhotoURL = nil
            placeDetails = nil
            photoFetchTimedOut = false
            // Use only the name for the query, relying on the coordinate bias for accuracy.
            let query = mapFeature?.title ?? mapItem.name ?? ""
            // Start a 5-second timeout timer in parallel
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if placeDetails == nil {
                    await MainActor.run { photoFetchTimedOut = true }
                }
            }
            do {
                let details = try await GooglePlacesAPIService.shared.placeDetails(forQuery: query, at: mapItem.placemark.coordinate)
                await MainActor.run {
                    placeDetails = details
                    if let ref = details.photoReference,
                       let url = GooglePlacesAPIService.shared.photoURL(for: ref, maxWidth: 600) {
                        placePhotoURL = url
                    }
                }
            } catch {
                print("Failed to fetch Google Places details: \(error.localizedDescription)")
            }
        }
=======
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
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

<<<<<<< HEAD
            return LocationView(selectedTab: $previewSelectedTab, mapItem: mapItem, mapFeature: nil)
=======
            return LocationView(selectedTab: $previewSelectedTab, mapItem: mapItem)
>>>>>>> 8785f90ee5a7a942c19e1e3757edbdc88383c05b
                .environmentObject(RouteViewModel())
                .frame(height: 300)
                .background(Color(UIColor.systemBackground))
                .previewLayout(.sizeThatFits)
        }
    }

    return LocationView_PreviewWrapper()
}
