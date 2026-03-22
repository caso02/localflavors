import SwiftUI

struct DishRevealAnimation: View {
    let dishNames: [String]
    @State private var revealedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(dishNames.prefix(revealedCount).enumerated()), id: \.offset) { index, name in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: revealedCount)
        .onAppear {
            revealDishes()
        }
    }

    private func revealDishes() {
        for index in dishNames.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                withAnimation {
                    revealedCount = index + 1
                }
            }
        }
    }
}
