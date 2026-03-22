import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Screen {
        case camera
        case analyzing
        case results
    }

    @Published var currentScreen: Screen = .camera
    @Published var detectedRestaurant: Restaurant?
    @Published var capturedPages: [UIImage] = []
    @Published var analysisResult: AnalysisResult?
    @Published var isLoading = false
    @Published var error: String?

    func reset() {
        currentScreen = .camera
        capturedPages = []
        analysisResult = nil
        error = nil
    }
}
