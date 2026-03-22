import Foundation

struct Restaurant: Identifiable, Codable {
    let id: String // Google Place ID
    let name: String
    let address: String
    let rating: Double?
    let totalRatings: Int?

    enum CodingKeys: String, CodingKey {
        case id = "placeId"
        case name
        case address
        case rating
        case totalRatings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        // Handle totalRatings as Int or Double
        if let intVal = try? container.decode(Int.self, forKey: .totalRatings) {
            totalRatings = intVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .totalRatings) {
            totalRatings = Int(doubleVal)
        } else {
            totalRatings = nil
        }
    }
}
