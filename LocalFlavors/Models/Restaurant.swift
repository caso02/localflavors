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

    // Memberwise init for programmatic construction
    init(id: String, name: String, address: String, rating: Double? = nil, totalRatings: Int? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.rating = rating
        self.totalRatings = totalRatings
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(totalRatings, forKey: .totalRatings)
    }
}
