import Foundation

struct AnalysisResult: Codable {
    let restaurant: Restaurant
    let topPicks: [DishAnalysis]
    let avoid: [DishAnalysis]
    let allDishes: [DishAnalysis]

    var mentionedDishes: [DishAnalysis] {
        allDishes.filter { $0.sentiment != .unmentioned }
    }

    var unmentionedDishes: [DishAnalysis] {
        allDishes.filter { $0.sentiment == .unmentioned }
    }
}
