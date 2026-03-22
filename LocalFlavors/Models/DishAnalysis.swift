import Foundation

struct DishAnalysis: Identifiable, Codable {
    let id: String
    let name: String
    let price: String?
    let score: Int // 1-10
    let mentions: Int
    let sentiment: Sentiment
    let summary: String
    let category: String?
    let courseType: String?  // "starter", "main", "dessert", "drink", "side", "menu"
    let baseGroup: String?  // Groups similar dishes (e.g. all poutine variants)
    let dietary: [String]?  // e.g. ["vegetarian", "vegan", "gluten-free"]

    // Custom decoder to handle score/mentions as Double from JSON (Gemini returns numbers)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Handle price as String or number from JSON
        if let strVal = try? container.decodeIfPresent(String.self, forKey: .price) {
            price = strVal
        } else if let numVal = try? container.decodeIfPresent(Double.self, forKey: .price) {
            price = String(format: "%.2f", numVal)
        } else {
            price = nil
        }
        // Handle both Int and Double from JSON
        if let intVal = try? container.decode(Int.self, forKey: .score) {
            score = intVal
        } else {
            score = Int(try container.decode(Double.self, forKey: .score))
        }
        if let intVal = try? container.decode(Int.self, forKey: .mentions) {
            mentions = intVal
        } else {
            mentions = Int(try container.decode(Double.self, forKey: .mentions))
        }
        sentiment = try container.decode(Sentiment.self, forKey: .sentiment)
        summary = try container.decode(String.self, forKey: .summary)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        courseType = try container.decodeIfPresent(String.self, forKey: .courseType)
        baseGroup = try container.decodeIfPresent(String.self, forKey: .baseGroup)
        dietary = try container.decodeIfPresent([String].self, forKey: .dietary)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, price, score, mentions, sentiment, summary
        case category, courseType, baseGroup, dietary
    }

    /// Parsed numeric price value (e.g. "CHF 18.50" → 18.50)
    var priceValue: Double? {
        guard let price else { return nil }
        // Remove currency symbols and whitespace, handle both . and , as decimal separators
        let cleaned = price
            .replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",", with: ".")
        // If multiple dots, take the last segment as decimals
        let parts = cleaned.split(separator: ".")
        if parts.count > 2 {
            let whole = parts.dropLast().joined()
            let decimal = parts.last ?? ""
            return Double("\(whole).\(decimal)")
        }
        return Double(cleaned)
    }

    /// Price-performance ratio (score per CHF, higher = better value)
    var valueScore: Double? {
        guard let pv = priceValue, pv > 0, sentiment != .unmentioned else { return nil }
        return Double(score) / pv
    }

    enum Sentiment: String, Codable {
        case positive
        case mixed
        case negative
        case unmentioned

        // Handle unexpected values from Gemini (e.g. "neutral" → .mixed)
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self).lowercased()
            switch value {
            case "positive": self = .positive
            case "mixed", "neutral": self = .mixed
            case "negative": self = .negative
            case "unmentioned", "unknown", "none": self = .unmentioned
            default: self = .unmentioned
            }
        }
    }

    /// Localized course type label
    var courseLabel: String {
        switch courseType {
        case "starter": return "Vorspeisen"
        case "main": return "Hauptspeisen"
        case "dessert": return "Desserts"
        case "drink": return "Getränke"
        case "side": return "Beilagen"
        case "menu": return "Menüs"
        default: return "Sonstiges"
        }
    }

    /// Icon for course type
    var courseIcon: String {
        switch courseType {
        case "starter": return "leaf"
        case "main": return "fork.knife"
        case "dessert": return "birthday.cake"
        case "drink": return "cup.and.saucer"
        case "side": return "plus.circle"
        case "menu": return "list.bullet.rectangle"
        default: return "questionmark.circle"
        }
    }
}
