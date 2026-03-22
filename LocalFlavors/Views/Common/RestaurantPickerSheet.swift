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
                if showRequiredHint {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text(String(localized: "picker.hint"))
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.1))
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(String(localized: "picker.search"), text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await search() } }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
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

                Group {
                    if isLoading {
                        Spacer()
                        ProgressView(String(localized: "picker.searching"))
                        Spacer()
                    } else if nearbyRestaurants.isEmpty && hasSearched {
                        Spacer()
                        ContentUnavailableView(
                            String(localized: "picker.noResults"),
                            systemImage: "mappin.slash",
                            description: Text(String(localized: "picker.noResults.hint"))
                        )
                        Spacer()
                    } else if nearbyRestaurants.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "picker.loading"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        List {
                            if let current = currentRestaurant {
                                Section {
                                    restaurantRow(current, isCurrent: true)
                                } header: {
                                    Label(String(localized: "picker.detected"), systemImage: "location.fill")
                                        .font(.caption.bold())
                                        .foregroundStyle(.green)
                                }
                            }

                            Section {
                                ForEach(filteredNearbyRestaurants) { restaurant in
                                    restaurantRow(restaurant, isCurrent: false)
                                }
                            } header: {
                                Text(hasSearched ? String(localized: "picker.searchResults") : String(localized: "picker.nearby"))
                                    .font(.caption.bold())
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle(String(localized: "picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "picker.cancel")) { dismiss() }
                }
            }
            .task {
                await loadNearby()
            }
        }
        .presentationDetents([.medium, .large])
    }

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
