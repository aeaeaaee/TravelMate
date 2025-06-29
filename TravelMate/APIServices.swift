//  A lightweight wrapper around the Google Places API (New) to fetch
//  details for a place (name, address, coordinate, optional photo).
//  The API key should be stored securely in Info.plist under the key
//  "GOOGLE_API_KEY". DO NOT hard-code production keys.
//
//  This implementation uses the modern Places API (New) endpoints,
//  which require POST requests with field masks.
//
//  For more information on migrating to the new Places API, see:
//  https://developers.google.com/maps/documentation/places/web-service/migration

import Foundation
import CoreLocation

// MARK: - Public Model

/// Represents the essential details returned from the Google Places API.
struct PlaceDetails: Hashable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    /// The reference name for the first photo if available. Convert this to a URL via `photoURL(for:maxWidth:)`.
    /// Example: "places/ChIJN1t_tDeuEmsRUsoyG83frY4/photos/..."
    let photoReference: String?

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(photoReference)
    }

    // MARK: - Equatable
    static func == (lhs: PlaceDetails, rhs: PlaceDetails) -> Bool {
        lhs.name == rhs.name &&
        lhs.address == rhs.address &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.photoReference == rhs.photoReference
    }
}

// MARK: - Service

/// A singleton service object that interacts with the Google Places API (New) REST APIs.
/// All network calls run on `URLSession.shared` with async/await.
@MainActor
final class GooglePlacesAPIService {
    // Singleton
    static let shared = GooglePlacesAPIService()
    private init() {}

    private let baseURL = "https://places.googleapis.com/v1/"
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - Public Async API

    /// Fetches `PlaceDetails` for a given text query using the Places *Text Search (New)* endpoint.
    /// This is the primary method for finding a place.
    /// - Parameter textQuery: Free-form text (e.g., place name + optional address).
    /// - Parameter coordinate: The coordinate to bias search results towards, improving accuracy.
    func placeDetails(forQuery textQuery: String, at coordinate: CLLocationCoordinate2D? = nil) async throws -> PlaceDetails {
        guard let apiKey = apiKey else { throw APIError.missingAPIKey }

        let url = URL(string: baseURL + "places:searchText")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Field mask specifies which fields to return, reducing cost and data usage.
        request.setValue("places.displayName,places.formattedAddress,places.location,places.photos", forHTTPHeaderField: "X-Goog-FieldMask")

        let locationBias: NewAPI.LocationBias?
        if let coord = coordinate {
            let location = NewAPI.Location(latitude: coord.latitude, longitude: coord.longitude)
            // A circle with a 1km radius is a reasonable bias
            let circle = NewAPI.Circle(center: location, radius: 1000)
            locationBias = NewAPI.LocationBias(circle: circle)
        } else {
            locationBias = nil
        }
        
        let requestBody = NewAPI.SearchRequest(
            textQuery: textQuery,
            languageCode: Locale.preferredLanguages.first ?? "en",
            locationBias: locationBias
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidServerResponse("Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }

        let apiResponse = try decoder.decode(NewAPI.SearchResponse.self, from: data)
        guard let place = apiResponse.places?.first else {
            throw APIError.placeNotFound(textQuery)
        }

        // Determine photo reference. If not provided in the search response, fetch via details endpoint.
        var photoRef = place.photos?.first?.name
        if photoRef == nil, let resourceName = place.name {
            photoRef = try await fetchFirstPhotoName(resourceName: resourceName)
        }

        let resultCoordinate = CLLocationCoordinate2D(
            latitude: place.location?.latitude ?? 0,
            longitude: place.location?.longitude ?? 0
        )

        return PlaceDetails(
            name: place.displayName?.text ?? "Unnamed Place",
            address: place.formattedAddress ?? "",
            coordinate: resultCoordinate,
            photoReference: photoRef
        )
    }

    /// Returns the full URL for a photo associated with a place.
    /// The new API requires the photo's `name` as the reference.
    func photoURL(for reference: String, maxWidth: Int = 400) -> URL? {
        guard let key = apiKey, !reference.isEmpty else { return nil }
        // The reference is the full resource name, e.g., "places/ChIJ.../photos/Aap..."
        let urlString = "\(baseURL)\(reference)/media?maxWidthPx=\(maxWidth)&key=\(key)"
        return URL(string: urlString)
    }

    // MARK: - Private Helpers

    /// Retrieves the API key from (1) a launch-time environment variable, or (2) `Info.plist`.
    // Helper to fetch first photo name when not present in text-search response
    private func fetchFirstPhotoName(resourceName: String) async throws -> String? {
        guard let apiKey = apiKey else { return nil }
        let url = URL(string: "\(baseURL)\(resourceName)?fields=photos")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        struct PhotoOnlyResponse: Decodable { let photos: [NewAPI.Photo]? }
        let resp = try decoder.decode(PhotoOnlyResponse.self, from: data)
        return resp.photos?.first?.name
    }

    private var apiKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String
    }
}

// MARK: - New API DTOs & Models

private enum NewAPI {
    struct SearchRequest: Encodable {
        let textQuery: String
        let languageCode: String
        let locationBias: LocationBias?
    }

    // A circular region to bias search results.
    struct LocationBias: Encodable {
        let circle: Circle
    }

    struct Circle: Encodable {
        let center: Location
        let radius: Double
    }

    struct SearchResponse: Decodable {
        let places: [Place]?
    }

    struct Place: Decodable {
        let name: String? // Note: This is the resource name, not the display name.
        let displayName: DisplayName?
        let formattedAddress: String?
        let location: Location?
        let photos: [Photo]?

        func toPlaceDetails() -> PlaceDetails {
            let coordinate = CLLocationCoordinate2D(
                latitude: location?.latitude ?? 0,
                longitude: location?.longitude ?? 0
            )
            return PlaceDetails(
                name: displayName?.text ?? "Unnamed Place",
                address: formattedAddress ?? "",
                coordinate: coordinate,
                photoReference: photos?.first?.name
            )
        }
    }

    struct DisplayName: Decodable {
        let text: String?
        let languageCode: String?
    }

    struct Location: Codable {
        let latitude: Double?
        let longitude: Double?
    }

    struct Photo: Decodable {
        /// The resource name of the photo, e.g., "places/{place_id}/photos/{photo_id}".
        let name: String
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidServerResponse(String)
    case placeNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Google Places API key is missing. Add it to Info.plist with key 'GOOGLE_API_KEY'."
        case .invalidURL:
            return "Failed to construct Google Places API URL."
        case .invalidServerResponse(let status):
            return "Google Places API returned an error: \(status)."
        case .placeNotFound(let query):
            return "No place found matching query: '\(query)'."
        }
    }
}
