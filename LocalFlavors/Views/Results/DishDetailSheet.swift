import SwiftUI

struct DishDetailSheet: View {
    let dish: DishAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with course type badge
                    VStack(alignment: .leading, spacing: 8) {
                        // Course type badge
                        if let courseType = dish.courseType {
                            HStack(spacing: 4) {
                                Image(systemName: dish.courseIcon)
                                    .font(.caption2)
                                Text(dish.courseLabel)
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dish.name)
                                    .font(.title2.bold())
                                if let category = dish.category {
                                    Text(category)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                // Dietary badges
                                if let dietary = dish.dietary, !dietary.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(dietary, id: \.self) { tag in
                                            HStack(spacing: 3) {
                                                Image(systemName: dietaryIcon(for: tag))
                                                    .font(.caption2)
                                                Text(dietaryLabel(for: tag))
                                                    .font(.caption2.bold())
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(dietaryColor(for: tag).opacity(0.12), in: Capsule())
                                            .foregroundStyle(dietaryColor(for: tag))
                                        }
                                    }
                                }
                            }

                            Spacer()

                            if let price = dish.price {
                                Text(price)
                                    .font(.title3.bold())
                            }
                        }
                    }

                    // Score ring & stats
                    if dish.sentiment != .unmentioned {
                        HStack(spacing: 20) {
                            // Score ring
                            ZStack {
                                Circle()
                                    .stroke(scoreColor.opacity(0.15), lineWidth: 6)
                                    .frame(width: 80, height: 80)
                                Circle()
                                    .trim(from: 0, to: CGFloat(dish.score) / 10.0)
                                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                VStack(spacing: -2) {
                                    Text("\(dish.score)")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreColor)
                                    Text("von 10")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                // Mentions as social proof
                                if dish.mentions > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.2.fill")
                                            .font(.caption)
                                            .foregroundStyle(scoreColor)
                                        Text("\(formattedMentions(dish.mentions))+ Gäste erwähnen dies")
                                            .font(.subheadline)
                                    }
                                }

                                // Sentiment
                                HStack(spacing: 6) {
                                    Image(systemName: sentimentIcon)
                                        .font(.caption)
                                        .foregroundStyle(scoreColor)
                                    Text(sentimentText)
                                        .font(.subheadline)
                                        .foregroundStyle(scoreColor)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }

                    // Value indicator
                    if let vs = dish.valueScore, vs > 0.4, dish.score >= 7 {
                        HStack(spacing: 8) {
                            Image(systemName: "banknote.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gutes Preis-Leistungs-Verhältnis")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.green)
                                if let price = dish.priceValue {
                                    Text("Score \(dish.score)/10 für \(dish.price ?? "") — \(String(format: "%.2f", vs)) Punkte/CHF")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Review summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Was Gäste sagen")
                            .font(.headline)

                        if dish.sentiment == .unmentioned {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Dieses Gericht wurde in den Rezensionen nicht erwähnt.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(dish.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func formattedMentions(_ count: Int) -> String {
        if count < 10 { return "\(count)" }
        if count < 100 { return "\(count / 10 * 10)" }
        return "\(count / 50 * 50)"
    }

    private func dietaryIcon(for tag: String) -> String {
        switch tag {
        case "vegan": return "leaf.circle.fill"
        case "vegetarian": return "leaf.fill"
        case "gluten-free": return "allergens"
        default: return "circle"
        }
    }

    private func dietaryLabel(for tag: String) -> String {
        switch tag {
        case "vegan": return "Vegan"
        case "vegetarian": return "Vegetarisch"
        case "gluten-free": return "Glutenfrei"
        default: return tag
        }
    }

    private func dietaryColor(for tag: String) -> Color {
        switch tag {
        case "vegan", "vegetarian": return .green
        case "gluten-free": return .orange
        default: return .gray
        }
    }

    private var scoreColor: Color {
        if dish.sentiment == .unmentioned { return .gray }
        switch dish.score {
        case 9...10: return Color(red: 0.1, green: 0.6, blue: 0.2)
        case 7...8: return .green
        case 5...6: return .orange
        case 3...4: return Color(red: 0.9, green: 0.3, blue: 0.1)
        default: return .red
        }
    }

    private var sentimentText: String {
        switch dish.sentiment {
        case .positive: "Durchweg positiv"
        case .mixed: "Gemischte Meinungen"
        case .negative: "Eher negativ"
        case .unmentioned: "Keine Daten"
        }
    }

    private var sentimentIcon: String {
        switch dish.sentiment {
        case .positive: "hand.thumbsup.fill"
        case .mixed: "hand.raised.fill"
        case .negative: "hand.thumbsdown.fill"
        case .unmentioned: "questionmark.circle"
        }
    }
}
