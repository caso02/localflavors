import SwiftUI

struct DishCardView: View {
    let dish: DishAnalysis
    let style: Style
    var animate: Bool = false
    var revealed: Bool = true

    enum Style {
        case topPick, avoid, list, value
    }

    var body: some View {
        switch style {
        case .topPick:
            topPickCard
                .scaleEffect(animate && !revealed ? 0.8 : 1.0)
                .opacity(animate && !revealed ? 0 : 1)
        case .avoid:
            avoidCard
        case .list:
            listCard
        case .value:
            valueCard
        }
    }

    // MARK: - Top Pick (large hero card with score ring)

    private var topPickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                RecommendationBadge(sentiment: dish.sentiment)
                Spacer()
                animatedScoreRing
            }

            Text(dish.name)
                .font(.title3.bold())
                .lineLimit(2)

            HStack(spacing: 6) {
                if let price = dish.price {
                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                dietaryBadges
            }

            Text(dish.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if dish.mentions > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(String(localized: "dish.guestsRecommend \(formattedMentions(dish.mentions))"))
                        .font(.caption2)
                }
                .foregroundStyle(scoreColor.opacity(0.8))
            }
        }
        .padding()
        .frame(width: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Avoid card (with concrete reason)

    private var avoidCard: some View {
        HStack(spacing: 12) {
            // Score ring for avoid
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(dish.score) / 10.0)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text("\(dish.score)")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(dish.name)
                    .font(.subheadline.bold())
                Text(dish.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if dish.mentions > 0 {
                    Text(String(localized: "dish.negativeMentions \(formattedMentions(dish.mentions))"))
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            Spacer()

            if let price = dish.price {
                Text(price)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - List card

    private var listCard: some View {
        HStack(spacing: 12) {
            sentimentIndicator

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(dish.name)
                        .font(.subheadline)
                    dietaryBadges
                }
                if dish.mentions > 0 {
                    Text(String(localized: "dish.mentioned \(formattedMentions(dish.mentions))"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let price = dish.price {
                Text(price)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            scoreView
        }
        .padding(.vertical, 4)
    }

    // MARK: - Components

    /// Circular score ring (for top pick cards)
    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.2), lineWidth: 4)
                .frame(width: 48, height: 48)
            Circle()
                .trim(from: 0, to: CGFloat(dish.score) / 10.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(dish.score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("/10")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sentimentIndicator: some View {
        Circle()
            .fill(scoreColor)
            .frame(width: 8, height: 8)
    }

    private var scoreView: some View {
        Group {
            if dish.sentiment != .unmentioned {
                Text("\(dish.score)/10")
                    .font(.caption.bold())
                    .foregroundStyle(scoreColor)
            }
        }
    }

    // MARK: - Value Card

    private var valueCard: some View {
        HStack(spacing: 12) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(dish.score) / 10.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text("\(dish.score)")
                    .font(.caption.bold())
                    .foregroundStyle(scoreColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dish.name)
                        .font(.subheadline.bold())
                    valueBadge
                }
                if let price = dish.price {
                    Text(price)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                dietaryBadges
            }

            Spacer()

            if dish.mentions > 0 {
                Text(String(localized: "dish.mentioned \(formattedMentions(dish.mentions))"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var valueBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 8))
            Text(String(localized: "dish.topScore"))
                .font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.green.opacity(0.15), in: Capsule())
        .foregroundStyle(.green)
    }

    // MARK: - Animated Score Ring

    private var animatedScoreRing: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.2), lineWidth: 4)
                .frame(width: 48, height: 48)
            Circle()
                .trim(from: 0, to: animate ? (revealed ? CGFloat(dish.score) / 10.0 : 0) : CGFloat(dish.score) / 10.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8).delay(0.2), value: revealed)
            VStack(spacing: -2) {
                Text("\(dish.score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("/10")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Dietary Badges

    private var dietaryBadges: some View {
        HStack(spacing: 4) {
            if let dietary = dish.dietary {
                if dietary.contains("vegan") {
                    dietaryPill(icon: "leaf.circle.fill", text: "Vegan", color: .green)
                } else if dietary.contains("vegetarian") {
                    dietaryPill(icon: "leaf.fill", text: "Vegi", color: .green)
                }
                if dietary.contains("gluten-free") {
                    dietaryPill(icon: "allergens", text: "GF", color: .orange)
                }
            }
        }
    }

    private func dietaryPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }

    func formattedMentions(_ count: Int) -> String {
        if count < 10 { return "\(count)" }
        if count < 100 { return "\(count / 10 * 10)" }
        return "\(count / 50 * 50)"
    }

    var scoreColor: Color {
        if dish.sentiment == .unmentioned { return .gray }
        switch dish.score {
        case 9...10: return Color(red: 0.1, green: 0.6, blue: 0.2)
        case 7...8: return .green
        case 5...6: return .orange
        case 3...4: return Color(red: 0.9, green: 0.3, blue: 0.1)
        default: return .red
        }
    }
}
