import SwiftUI

struct RestaurantBannerView: View {
    let restaurant: Restaurant?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(restaurant != nil ? .green : .orange)
                    .frame(width: 8, height: 8)

                if let restaurant {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(restaurant.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)

                        HStack(spacing: 6) {
                            if let rating = restaurant.rating {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }

                            if let total = restaurant.totalRatings {
                                Text("·")
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("\(total) Bewertungen")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white.opacity(0.7))
                        Text("Restaurant wird erkannt...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.3), value: restaurant?.id)
    }
}
