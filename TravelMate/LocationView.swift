import SwiftUI
import MapKit

// MKLookAroundSceneRequest is used locally within a @Sendable context; mark as unchecked Sendable for Swift concurrency.
extension MKLookAroundSceneRequest: @unchecked Sendable {}
// MKLookAroundScene is used only for value extraction inside Sendable closures; mark as unchecked Sendable.
extension MKLookAroundScene: @unchecked Sendable {}

struct LocationView: View {
    // State variables for Look Around scene
    @State private var lookAroundScene: MKLookAroundScene? = nil
    @State private var isLookAroundAvailable: Bool = true // Assume available until proven otherwise
    @EnvironmentObject var routeViewModel: RouteViewModel
    @Environment(\.openURL) var openURL
    @Binding var selectedTab: MapView.Tab // Use MapView.Tab as confirmed by user
    let mapItem: MKMapItem
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
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Display an image for the location, trying MapKit's image first, then Google's.
            if placePhotoURL != nil {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let url = placePhotoURL {
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

                // Google Images search button (moved to photo overlay)

            }
            .padding(.bottom, 8) // Add some padding below the buttons

            VStack(alignment: .leading, spacing: 8) {
                if let address = placeDetails?.address ?? mapItem.placemark.title {
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

            return LocationView(selectedTab: $previewSelectedTab, mapItem: mapItem, mapFeature: nil)
                .environmentObject(RouteViewModel())
                .frame(height: 300)
                .background(Color(UIColor.systemBackground))
                .previewLayout(.sizeThatFits)
        }
    }

    return LocationView_PreviewWrapper()
}
