import SwiftUI
import CoreLocation

struct RestaurantPickerSheet: View {
    let currentRestaurant: Restaurant?
    let location: CLLocationCoordinate2D?
    var showRequiredHint: Bool = false
    let onSelect: (Restaurant) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var nearbyRestaurants: [Restaurant] = []
    @State private var isLoading = false
    @State private var hasSearched = false

    private let apiService = APIService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hint when restaurant is required
                if showRequiredHint {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Wähle ein Restaurant um die Analyse zu starten.")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.1))
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Restaurant suchen...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await search() } }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            // Reset to nearby when clearing search
                            if hasSearched {
                                hasSearched = false
                                Task { await loadNearby() }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding()

                // Results
                Group {
                    if isLoading {
                        Spacer()
                        ProgressView("Suche...")
                        Spacer()
                    } else if nearbyRestaurants.isEmpty && hasSearched {
                        Spacer()
                        ContentUnavailableView(
                            "Keine Restaurants gefunden",
                            systemImage: "mappin.slash",
                            description: Text("Versuche einen anderen Suchbegriff.")
                        )
                        Spacer()
                    } else if nearbyRestaurants.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Restaurants in der Nähe werden geladen...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        List {
                            // Currently detected restaurant always at top
                            if let current = currentRestaurant {
                                Section {
                                    restaurantRow(current, isCurrent: true)
                                } header: {
                                    Label("Erkannt", systemImage: "location.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                }
                            }

                            // Nearby / search results (excluding current to avoid duplicate)
                            Section {
                                ForEach(filteredNearbyRestaurants) { restaurant in
                                    restaurantRow(restaurant, isCurrent: false)
                                }
                            } header: {
                                Text(hasSearched ? "Suchergebnisse" : "In der Nähe")
                                    .font(.caption.bold())
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Restaurant wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task {
                await loadNearby()
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Nearby restaurants excluding the current one (to avoid duplicate)
    private var filteredNearbyRestaurants: [Restaurant] {
        guard let currentId = currentRestaurant?.id else { return nearbyRestaurants }
        return nearbyRestaurants.filter { $0.id != currentId }
    }

    private func restaurantRow(_ restaurant: Restaurant, isCurrent: Bool) -> some View {
        Button {
            onSelect(restaurant)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                    Text(restaurant.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let rating = restaurant.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let total = restaurant.totalRatings {
                                Text("(\(total))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
    }

    private func loadNearby() async {
        guard let location else { return }
        guard nearbyRestaurants.isEmpty else { return }
        isLoading = true
        do {
            nearbyRestaurants = try await apiService.searchRestaurants(
                query: nil,
                latitude: location.latitude,
                longitude: location.longitude
            )
        } catch {
            print("[RestaurantPicker] loadNearby error: \(error)")
        }
        isLoading = false
    }

    private func search() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let location else { return }
        isLoading = true
        hasSearched = true

        do {
            nearbyRestaurants = try await apiService.searchRestaurants(
                query: searchText,
                latitude: location.latitude,
                longitude: location.longitude
            )
        } catch {
            print("[RestaurantPicker] search error: \(error)")
            nearbyRestaurants = []
        }
        isLoading = false
    }
}
