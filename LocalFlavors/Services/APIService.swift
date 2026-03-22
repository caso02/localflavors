import Foundation
import FirebaseFunctions

final class APIService {
    private lazy var functions = Functions.functions()

    // MARK: - Restaurant Detection

    func detectRestaurant(latitude: Double, longitude: Double) async throws -> Restaurant {
        let result = try await functions.httpsCallable("detectRestaurant").call([
            "latitude": latitude,
            "longitude": longitude
        ])

        guard let data = result.data as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(Restaurant.self, from: jsonData)
    }

    // MARK: - Restaurant Search

    func searchRestaurants(query: String?, latitude: Double, longitude: Double) async throws -> [Restaurant] {
        var params: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        if let query, !query.isEmpty {
            params["query"] = query
        }

        let result = try await functions.httpsCallable("searchNearbyRestaurants").call(params)

        guard let data = result.data as? [String: Any],
              let restaurantsData = data["restaurants"] as? [[String: Any]] else {
            throw APIError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: restaurantsData)
        return try JSONDecoder().decode([Restaurant].self, from: jsonData)
    }

    // MARK: - Menu Analysis

    func analyzeMenu(placeId: String, restaurantName: String, images: [Data]) async throws -> AnalysisResult {
        let base64Images = images.map { $0.base64EncodedString() }

        let callable = functions.httpsCallable("analyzeMenu")
        callable.timeoutInterval = 300
        let result = try await callable.call([
            "placeId": placeId,
            "restaurantName": restaurantName,
            "images": base64Images
        ])

        guard let data = result.data as? [String: Any] else {
            throw APIError.invalidResponse
        }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(AnalysisResult.self, from: jsonData)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .serverError(let message):
            return message
        }
    }
}
