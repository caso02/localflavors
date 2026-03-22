import SwiftUI

struct RecommendationBadge: View {
    let sentiment: DishAnalysis.Sentiment

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor, in: Capsule())
        .foregroundStyle(foregroundColor)
    }

    private var icon: String {
        switch sentiment {
        case .positive: "flame.fill"
        case .mixed: "equal.circle"
        case .negative: "xmark.circle"
        case .unmentioned: "minus.circle"
        }
    }

    private var text: String {
        switch sentiment {
        case .positive: "Must Try"
        case .mixed: "Solide"
        case .negative: "Meiden"
        case .unmentioned: "Keine Daten"
        }
    }

    private var backgroundColor: Color {
        switch sentiment {
        case .positive: .green.opacity(0.15)
        case .mixed: .yellow.opacity(0.15)
        case .negative: .red.opacity(0.15)
        case .unmentioned: .gray.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch sentiment {
        case .positive: .green
        case .mixed: .orange
        case .negative: .red
        case .unmentioned: .gray
        }
    }
}
