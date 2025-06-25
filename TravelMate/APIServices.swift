//  APIServices.swift
//  TravelMate
//
//  Created by Cascade AI
//
//  A lightweight wrapper around the Google Places Web Service to fetch
//  details for a place (name, address, coordinate, optional photo).
//  The API key should be stored securely in Info.plist under the key
//  "GOOGLE_API_KEY". DO NOT hard-code production keys.
//
//  Usage Example (async/await):
//  let details = try await GooglePlacesAPIService.shared.placeDetails(for: placeID)
//  let photoURL = GooglePlacesAPIService.shared.photoURL(for: details.photoReference)
//
//  For older callers you can use the completion-handler variants provided.

//  For more information on the Google Places Web Service, see
//  https://developers.google.com/maps/documentation/places/web-service/overview?hl=zh-tw

import Foundation
import CoreLocation

// MARK: - Public Model

/// Represents the essential details returned from the Google Places Details endpoint.
struct PlaceDetails: Hashable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    /// The first photo reference if available. You can convert this to a URL via `photoURL(for:maxWidth:)`.
    let photoReference: String?

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
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

/// A singleton service object that interacts with the Google Places Web Service REST APIs.
/// All network calls run on `URLSession.shared` with async/await.
@MainActor
final class GooglePlacesAPIService {
    // Singleton
    static let shared = GooglePlacesAPIService()

    private init() {}

    // MARK: - Public Async API

    /// Fetches `PlaceDetails` for the given Place ID using the Places *Details* endpoint.
    /// - Parameter placeID: The Google Place ID.
    /// - Returns: A populated `PlaceDetails` struct.
    func placeDetails(for placeID: String) async throws -> PlaceDetails {
        let url = try buildDetailsURL(placeID: placeID)
        let (data, _) = try await URLSession.shared.data(from: url)
        let apiResponse = try JSONDecoder().decode(GMSPlaceDetailsResponse.self, from: data)
        guard apiResponse.status == "OK", let result = apiResponse.result else {
            throw APIError.invalidServerResponse(apiResponse.status ?? "UNKNOWN_STATUS")
        }
        return result.toPlaceDetails()
    }

    /// Convenience wrapper around `findPlaceID(for:)` followed by `placeDetails(for:)`.
    /// - Parameter textQuery: Free-form text (e.g., place name + optional address).
    func placeDetails(forTextQuery textQuery: String) async throws -> PlaceDetails {
        let placeID = try await findPlaceID(for: textQuery)
        return try await placeDetails(for: placeID)
    }

    /// Returns the full URL for a photo associated with a place.
    /// Google does not return direct image URLs – you must use their *Photo* endpoint with a `photo_reference`.
    func photoURL(for reference: String, maxWidth: Int = 400) -> URL? {
        guard let key = apiKey, !reference.isEmpty else { return nil }
        var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/place/photo")
        comps?.queryItems = [
            URLQueryItem(name: "maxwidth", value: "\(maxWidth)"),
            URLQueryItem(name: "photoreference", value: reference),
            URLQueryItem(name: "key", value: key)
        ]
        return comps?.url
    }

    // MARK: - Public Completion-Handler API (legacy callers)

    func placeDetails(placeID: String, completion: @escaping (Result<PlaceDetails, Error>) -> Void) {
        Task {
            do {
                let details = try await placeDetails(for: placeID)
                completion(.success(details))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func placeDetails(textQuery: String, completion: @escaping (Result<PlaceDetails, Error>) -> Void) {
        Task {
            do {
                let details = try await placeDetails(forTextQuery: textQuery)
                completion(.success(details))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private Helpers

    /// Retrieves the API key from (1) a launch-time environment variable, or (2) `Info.plist`.
    /// This lets you keep secrets out of the repo and swap keys per-scheme with ease.
    private var apiKey: String? {
        // 1. Xcode scheme → Run → Environment Variables
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        // 2. Fallback to bundled Info.plist (supports build-setting substitution)
        return Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String
    }

    private func buildDetailsURL(placeID: String) throws -> URL {
        guard let key = apiKey, !key.isEmpty else {
            throw APIError.missingAPIKey
        }
        var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")
        comps?.queryItems = [
            URLQueryItem(name: "place_id", value: placeID),
            URLQueryItem(name: "fields", value: "name,formatted_address,geometry,photos"),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "language", value: Locale.preferredLanguages.first ?? "en")
        ]
        guard let url = comps?.url else { throw APIError.invalidURL }
        return url
    }

    private func buildFindPlaceURL(query: String) throws -> URL {
        guard let key = apiKey, !key.isEmpty else { throw APIError.missingAPIKey }
        var comps = URLComponents(string: "https://maps.googleapis.com/maps/api/place/findplacefromtext/json")
        comps?.queryItems = [
            URLQueryItem(name: "input", value: query),
            URLQueryItem(name: "inputtype", value: "textquery"),
            URLQueryItem(name: "fields", value: "place_id"),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "language", value: Locale.preferredLanguages.first ?? "en")
        ]
        guard let url = comps?.url else { throw APIError.invalidURL }
        return url
    }

    private func findPlaceID(for textQuery: String) async throws -> String {
        let url = try buildFindPlaceURL(query: textQuery)
        let (data, _) = try await URLSession.shared.data(from: url)
        let apiResponse = try JSONDecoder().decode(GMSFindPlaceResponse.self, from: data)
        guard apiResponse.status == "OK", let placeID = apiResponse.candidates?.first?.place_id else {
            throw APIError.placeNotFound(textQuery)
        }
        return placeID
    }
}

// MARK: - Response DTOs

private struct GMSPlaceDetailsResponse: Decodable {
    let status: String?
    let result: GMSPlaceResult?
}

private struct GMSPlaceResult: Decodable {
    let name: String?
    let formatted_address: String?
    let geometry: GMSGeometry?
    let photos: [GMSPhoto]?

    func toPlaceDetails() -> PlaceDetails {
        let coord = geometry?.location ?? .init(lat: 0, lng: 0)
        let coordinate = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
        let photoRef = photos?.first?.photo_reference
        return PlaceDetails(
            name: name ?? "Unnamed Place",
            address: formatted_address ?? "",
            coordinate: coordinate,
            photoReference: photoRef
        )
    }
}

private struct GMSGeometry: Decodable {
    let location: GMSLocation
}

private struct GMSLocation: Decodable {
    let lat: Double
    let lng: Double
}

private struct GMSPhoto: Decodable {
    let photo_reference: String
}

private struct GMSFindPlaceResponse: Decodable {
    let status: String?
    let candidates: [GMSFindPlaceCandidate]?
}

private struct GMSFindPlaceCandidate: Decodable {
    let place_id: String
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