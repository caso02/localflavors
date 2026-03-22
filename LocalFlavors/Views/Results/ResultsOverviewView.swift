import SwiftUI

struct ResultsOverviewView: View {
    let result: AnalysisResult
    let onNewScan: () -> Void
    @State private var selectedDish: DishAnalysis?
    @State private var showUnmentioned = false
    @State private var expandedCourses: Set<String> = ["main"] // Hauptspeisen standardmässig offen
    @State private var appeared = false
    @State private var selectedFilter: DietaryFilter = .all
    @State private var revealedCards: Set<String> = []

    enum DietaryFilter: String, CaseIterable {
        case all = "Alle"
        case vegetarian = "Vegetarisch"
        case vegan = "Vegan"
        case glutenFree = "Glutenfrei"

        var filterKey: String? {
            switch self {
            case .all: return nil
            case .vegetarian: return "vegetarian"
            case .vegan: return "vegan"
            case .glutenFree: return "gluten-free"
            }
        }

        var icon: String {
            switch self {
            case .all: return "fork.knife"
            case .vegetarian: return "leaf.fill"
            case .vegan: return "leaf.circle.fill"
            case .glutenFree: return "allergens"
            }
        }
    }

    // Dietary filtering
    private func matchesFilter(_ dish: DishAnalysis) -> Bool {
        guard let key = selectedFilter.filterKey else { return true }
        return dish.dietary?.contains(key) ?? false
    }

    // Group dishes by courseType
    private var mentionedDishes: [DishAnalysis] {
        result.allDishes.filter { $0.sentiment != .unmentioned && matchesFilter($0) }
    }

    private var unmentionedDishes: [DishAnalysis] {
        result.allDishes.filter { $0.sentiment == .unmentioned && matchesFilter($0) }
    }

    /// Best value dishes (top 3 by score/price ratio, score >= 7)
    private var bestValueDishes: [DishAnalysis] {
        Array(result.allDishes
            .filter { $0.valueScore != nil && $0.sentiment != .unmentioned && $0.score >= 7 && matchesFilter($0) }
            .sorted { ($0.valueScore ?? 0) > ($1.valueScore ?? 0) }
            .prefix(3))
    }

    /// Count of dishes matching each dietary filter
    private func dietaryCount(for filter: DietaryFilter) -> Int {
        guard let key = filter.filterKey else { return result.allDishes.count }
        return result.allDishes.filter { $0.dietary?.contains(key) ?? false }.count
    }

    private var courseOrder: [String] {
        ["starter", "main", "dessert", "side", "drink", "menu"]
    }

    /// Groups mentioned dishes by courseType, preserving order
    private var groupedByCourse: [(courseType: String, dishes: [DishAnalysis])] {
        var groups: [String: [DishAnalysis]] = [:]
        for dish in mentionedDishes {
            let key = dish.courseType ?? "other"
            groups[key, default: []].append(dish)
        }
        let ordered = courseOrder.compactMap { course -> (String, [DishAnalysis])? in
            guard let dishes = groups[course], !dishes.isEmpty else { return nil }
            return (course, dishes)
        }
        if let other = groups["other"], !other.isEmpty {
            return ordered + [("other", other)]
        }
        return ordered
    }

    /// Top picks grouped by course type (for display sections), filtered by dietary
    private var topPicksByCourse: [(courseType: String, dishes: [DishAnalysis])] {
        let filtered = result.topPicks.filter { matchesFilter($0) }
        var groups: [String: [DishAnalysis]] = [:]
        for dish in filtered {
            let key = dish.courseType ?? "main"
            groups[key, default: []].append(dish)
        }
        return ["starter", "main", "dessert"].compactMap { course -> (String, [DishAnalysis])? in
            guard let dishes = groups[course], !dishes.isEmpty else { return nil }
            return (course, dishes)
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                scrollContent
                    .frame(width: geo.size.width)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onNewScan()
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(item: $selectedDish) { dish in
                DishDetailSheet(dish: dish)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                // Haptic feedback on first appearance + staggered card reveal
                if !appeared {
                    appeared = true
                    HapticsService.success()

                    // Stagger reveal top pick cards
                    let allTopPickIds = result.topPicks.map(\.id)
                    for (index, id) in allTopPickIds.enumerated() {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15 + 0.3) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                _ = revealedCards.insert(id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                restaurantHeader
                analysisSummaryBanner
                dietaryFilterChips

                if !topPicksByCourse.isEmpty {
                    topPicksSection
                }

                if !bestValueDishes.isEmpty {
                    bestValueSection
                }

                if !result.avoid.isEmpty {
                    avoidSection
                }

                allDishesSection
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
    }

    // MARK: - Restaurant Header

    private var restaurantHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.restaurant.name)
                    .font(.title2.bold())
                Text(result.restaurant.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let rating = result.restaurant.rating {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline.bold())
                    }
                    if let total = result.restaurant.totalRatings {
                        Text("\(total) Bewertungen")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Analysis Summary Banner

    private var analysisSummaryBanner: some View {
        HStack(spacing: 16) {
            summaryItem(
                icon: "menucard",
                value: "\(result.allDishes.count)",
                label: "Gerichte"
            )
            summaryDivider
            summaryItem(
                icon: "text.quote",
                value: result.restaurant.totalRatings.map { "\($0)" } ?? "–",
                label: "Reviews"
            )
            summaryDivider
            summaryItem(
                icon: "flame.fill",
                value: "\(result.topPicks.count)",
                label: "Empfehlungen"
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func summaryItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 1, height: 36)
    }

    // MARK: - Dietary Filter Chips

    private var dietaryFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DietaryFilter.allCases, id: \.self) { filter in
                    let count = dietaryCount(for: filter)
                    let isSelected = selectedFilter == filter

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                        HapticsService.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                                .font(.caption2)
                            Text(filter.rawValue)
                                .font(.caption.bold())
                            if filter != .all {
                                Text("(\(count))")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Top Picks (grouped by course)

    private var topPicksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Unsere Empfehlungen", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.orange)
                .padding(.horizontal)

            ForEach(topPicksByCourse, id: \.courseType) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Course type sub-header
                    HStack(spacing: 6) {
                        Image(systemName: courseIcon(for: group.courseType))
                            .font(.caption)
                        Text(topPickLabel(for: group.courseType))
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(group.dishes) { dish in
                                DishCardView(dish: dish, style: .topPick, animate: true, revealed: revealedCards.contains(dish.id))
                                    .onTapGesture { selectedDish = dish }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Best Value

    private var bestValueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Top Preis-Leistung", systemImage: "banknote.fill")
                .font(.headline)
                .foregroundStyle(.green)
                .padding(.horizontal)

            ForEach(bestValueDishes) { dish in
                DishCardView(dish: dish, style: .value)
                    .onTapGesture { selectedDish = dish }
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Avoid

    private var avoidSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lieber nicht", systemImage: "hand.thumbsdown.fill")
                .font(.headline)
                .foregroundStyle(.red)
                .padding(.horizontal)

            ForEach(result.avoid) { dish in
                DishCardView(dish: dish, style: .avoid)
                    .onTapGesture { selectedDish = dish }
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - All Dishes (collapsible sections)

    private var allDishesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alle Gerichte")
                .font(.headline)
                .padding(.horizontal)

            // Mentioned dishes grouped by course (collapsible)
            ForEach(groupedByCourse, id: \.courseType) { group in
                collapsibleCourseSection(courseType: group.courseType, dishes: group.dishes)
            }

            // Unmentioned dishes (collapsible)
            if !unmentionedDishes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showUnmentioned.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showUnmentioned ? "chevron.down" : "chevron.right")
                                .font(.caption2.bold())
                                .frame(width: 12)
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                            Text("Nicht erwähnt (\(unmentionedDishes.count))")
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }

                    if showUnmentioned {
                        ForEach(unmentionedDishes) { dish in
                            DishCardView(dish: dish, style: .list)
                                .onTapGesture { selectedDish = dish }
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    private func collapsibleCourseSection(courseType: String, dishes: [DishAnalysis]) -> some View {
        let isExpanded = expandedCourses.contains(courseType)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedCourses.remove(courseType)
                    } else {
                        expandedCourses.insert(courseType)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.bold())
                        .frame(width: 12)
                    Image(systemName: courseIcon(for: courseType))
                        .font(.caption)
                    Text("\(courseLabel(for: courseType)) (\(dishes.count))")
                        .font(.subheadline.bold())
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }

            if isExpanded {
                ForEach(dishes) { dish in
                    DishCardView(dish: dish, style: .list)
                        .onTapGesture { selectedDish = dish }
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Helpers

    private func topPickLabel(for type: String) -> String {
        switch type {
        case "starter": return "Beste Vorspeisen"
        case "main": return "Beste Hauptgerichte"
        case "dessert": return "Beste Desserts"
        default: return "Empfehlungen"
        }
    }

    private func courseLabel(for type: String) -> String {
        switch type {
        case "starter": return "Vorspeisen"
        case "main": return "Hauptspeisen"
        case "dessert": return "Desserts"
        case "drink": return "Getränke"
        case "side": return "Beilagen"
        case "menu": return "Menüs"
        default: return "Sonstiges"
        }
    }

    private func courseIcon(for type: String) -> String {
        switch type {
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
