import SwiftUI

struct AnalysisLoadingView: View {
    @State private var dotCount = 0
    @State private var phase: AnalysisPhase = .ocr
    let capturedImage: UIImage?

    enum AnalysisPhase: Int, CaseIterable {
        case ocr = 0
        case reviews = 1
        case scoring = 2

        var icon: String {
            switch self {
            case .ocr: return "doc.text.viewfinder"
            case .reviews: return "text.quote"
            case .scoring: return "star.fill"
            }
        }

        var title: String {
            switch self {
            case .ocr: return "Speisekarte wird erkannt"
            case .reviews: return "Bewertungen werden durchsucht"
            case .scoring: return "Empfehlungen werden erstellt"
            }
        }

        var subtitle: String {
            switch self {
            case .ocr: return "Gerichte und Preise werden aus dem Foto extrahiert"
            case .reviews: return "Google Reviews und Online-Quellen werden analysiert"
            case .scoring: return "Gerichte werden bewertet und sortiert"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background: blurred captured image
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 20)
                    .overlay(Color.black.opacity(0.6))
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 32) {
                Spacer()

                // Animated icon
                Image(systemName: phase.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                    .id(phase)

                // Phase title with dots
                VStack(spacing: 8) {
                    Text(phase.title + String(repeating: ".", count: dotCount))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .animation(.none, value: dotCount)

                    Text(phase.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Progress steps
                VStack(spacing: 12) {
                    ForEach(AnalysisPhase.allCases, id: \.rawValue) { step in
                        progressRow(step: step)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Dot animation
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                dotCount = (dotCount + 1) % 4
            }

            // Phase progression (estimated timings — optimized pipeline)
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .reviews
                }
                HapticsService.light()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .scoring
                }
                HapticsService.light()
            }
        }
    }

    private func progressRow(step: AnalysisPhase) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if step.rawValue < phase.rawValue {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body)
                } else if step == phase {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 22, height: 22)

            Text(step.title)
                .font(.subheadline)
                .foregroundStyle(step.rawValue <= phase.rawValue ? .white : .white.opacity(0.4))

            Spacer()
        }
    }
}
