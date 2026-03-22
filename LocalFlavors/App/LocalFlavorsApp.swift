import SwiftUI
import FirebaseCore
import FirebaseFunctions

@main
struct LocalFlavorsApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()

        // Use local emulator for development
        // Use Mac's local IP for real device, 127.0.0.1 for Simulator
        #if DEBUG
        Functions.functions().useEmulator(withHost: "192.168.1.61", port: 5001)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
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
            .environmentObject(appState)
        }
    }
}
