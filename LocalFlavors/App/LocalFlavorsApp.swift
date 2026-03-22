import SwiftUI
import FirebaseCore
import FirebaseFunctions

@main
struct LocalFlavorsApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        FirebaseApp.configure()

        // Toggle: Comment out for CLOUD, uncomment for LOCAL emulator
        // Functions.functions().useEmulator(withHost: "192.168.1.61", port: 5001)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    switch appState.currentScreen {
                    case .camera:
                        CameraView()
                    case .analyzing:
                        AnalysisLoadingView(capturedImage: appState.capturedPages.first)
                    case .results:
                        if let result = appState.analysisResult {
                            ResultsOverviewView(result: result) {
                                appState.reset()
                            }
                        } else {
                            CameraView()
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: hasSeenOnboarding)
            .environmentObject(appState)
        }
    }
}
