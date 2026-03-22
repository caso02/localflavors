import Foundation

/// Persists scan results locally using UserDefaults (JSON encoded).
/// Keeps the last 20 scans, oldest are evicted automatically.
final class ScanHistoryService {
    static let shared = ScanHistoryService()
    private let key = "scanHistory"
    private let maxEntries = 20

    private init() {}

    // MARK: - Public API

    func save(_ result: AnalysisResult) {
        var entries = loadAll()

        let entry = ScanHistoryEntry(
            id: UUID().uuidString,
            date: Date(),
            restaurantName: result.restaurant.name,
            restaurantAddress: result.restaurant.address,
            restaurantRating: result.restaurant.rating,
            restaurantTotalRatings: result.restaurant.totalRatings,
            placeId: result.restaurant.id,
            dishCount: result.allDishes.count,
            topPickNames: Array(result.topPicks.prefix(3).map(\.name)),
            topPickScore: result.topPicks.first?.score,
            result: result
        )

        // Remove existing entry for same restaurant (update)
        entries.removeAll { $0.placeId == result.restaurant.id }

        // Insert at front
        entries.insert(entry, at: 0)

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Persist
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func loadAll() -> [ScanHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([ScanHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    func delete(_ entryId: String) {
        var entries = loadAll()
        entries.removeAll { $0.id == entryId }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - History Entry Model

struct ScanHistoryEntry: Identifiable, Codable {
    let id: String
    let date: Date
    let restaurantName: String
    let restaurantAddress: String
    let restaurantRating: Double?
    let restaurantTotalRatings: Int?
    let placeId: String
    let dishCount: Int
    let topPickNames: [String]
    let topPickScore: Int?
    let result: AnalysisResult

    /// Relative time string (e.g. "Heute, 14:30" or "Gestern" or "23. März")
    var relativeDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Heute,' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Gestern,' HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE, HH:mm" // e.g. "Montag, 14:30"
        } else {
            formatter.dateFormat = "d. MMMM" // e.g. "23. März"
        }

        return formatter.string(from: date)
    }
}
