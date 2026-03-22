import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()
    @StateObject private var scanSession = ScanSession()
    @State private var showRestaurantPicker = false
    @State private var showRestaurantRequired = false
    @State private var isCapturing = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let apiService = APIService()
    private let maxPages = 8

    private var isLandscape: Bool { verticalSizeClass == .compact }
    private var isAtPageLimit: Bool { scanSession.pageCount >= maxPages }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewLayer(session: cameraService.session)
                .ignoresSafeArea()

            if isLandscape {
                landscapeOverlay
            } else {
                portraitOverlay
            }

            // Permission denied overlay
            if !cameraService.isAuthorized {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Kamerazugriff benötigt")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Öffne die Einstellungen und erlaube Local Flavors den Kamerazugriff.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showRestaurantPicker) {
            RestaurantPickerSheet(
                currentRestaurant: appState.detectedRestaurant,
                location: locationService.currentLocation,
                showRequiredHint: showRestaurantRequired,
                onSelect: { restaurant in
                    appState.detectedRestaurant = restaurant
                    showRestaurantRequired = false
                }
            )
        }
        .onAppear {
            cameraService.startSession()
            locationService.requestPermission()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()

            // Reset scan session when returning from results (new scan)
            if appState.analysisResult == nil && scanSession.hasPages {
                scanSession.reset()
            }
        }
        .onDisappear {
            cameraService.stopSession()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onChange(of: locationService.locationUpdateCount) { _, _ in
            guard let location = locationService.currentLocation, appState.detectedRestaurant == nil else { return }
            Task { await detectRestaurant(latitude: location.latitude, longitude: location.longitude) }
        }
    }

    // MARK: - Portrait Layout (existing)

    private var portraitOverlay: some View {
        VStack {
            RestaurantBannerView(
                restaurant: appState.detectedRestaurant,
                onTap: { showRestaurantPicker = true }
            )
            .padding(.top, 8)

            Spacer()

            if scanSession.hasPages {
                PageThumbnailStrip(session: scanSession)
                    .padding(.bottom, 8)
            }

            captureControls
                .padding(.bottom, 30)
        }
    }

    // MARK: - Landscape Layout

    private var landscapeOverlay: some View {
        HStack {
            // Restaurant banner on the left
            VStack {
                RestaurantBannerView(
                    restaurant: appState.detectedRestaurant,
                    onTap: { showRestaurantPicker = true }
                )
                .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: 200)

            Spacer()

            // Controls on the right side
            VStack(spacing: 20) {
                Spacer()

                if scanSession.hasPages {
                    PageThumbnailStrip(session: scanSession)
                        .frame(maxWidth: 200)
                }

                // Photo picker
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 8,
                    matching: .images
                ) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.body)
                                .foregroundStyle(.white)
                        }
                }

                // Shutter button
                Button {
                    Task { await capturePhoto() }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(isAtPageLimit ? .gray : .white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(isAtPageLimit ? .gray : .white)
                            .frame(width: 62, height: 62)
                            .scaleEffect(isCapturing ? 0.85 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isCapturing)
                    }
                }
                .disabled(isCapturing || isAtPageLimit)

                if scanSession.hasPages {
                    Button {
                        Task { await startAnalysis() }
                    } label: {
                        Circle()
                            .fill(.green)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                            }
                    }
                }

                // Page counter
                if scanSession.hasPages {
                    Text("\(scanSession.pageCount)/\(maxPages)")
                        .font(.caption2.bold())
                        .foregroundStyle(isAtPageLimit ? .orange : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()
            }
            .padding(.trailing, 20)
        }
    }

    // MARK: - Shared capture controls (portrait)

    private var captureControls: some View {
        HStack(spacing: 40) {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 8,
                matching: .images
            ) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                Task { await loadSelectedPhotos(items) }
            }

            VStack(spacing: 8) {
                Button {
                    Task { await capturePhoto() }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(isAtPageLimit ? .gray : .white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(isAtPageLimit ? .gray : .white)
                            .frame(width: 62, height: 62)
                            .scaleEffect(isCapturing ? 0.85 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isCapturing)
                    }
                }
                .disabled(isCapturing || isAtPageLimit)

                if scanSession.hasPages {
                    Text("\(scanSession.pageCount)/\(maxPages)")
                        .font(.caption2.bold())
                        .foregroundStyle(isAtPageLimit ? .orange : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }

            if scanSession.hasPages {
                Button {
                    Task { await startAnalysis() }
                } label: {
                    Circle()
                        .fill(.green)
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                        }
                }
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 50, height: 50)
            }
        }
    }

    // MARK: - Actions

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Normalize orientation + resize + re-compress to strip excess color data
                let normalized = normalizeOrientation(uiImage)
                let resized = resizeImage(normalized, maxDimension: 2400)

                // Re-encode as JPEG and back to strip extra metadata/color profiles
                // This makes library photos comparable in size to camera captures
                guard let jpegData = resized.jpegData(compressionQuality: 0.7),
                      let cleaned = UIImage(data: jpegData) else { continue }

                print("[CameraView] Photo picker: \(Int(uiImage.size.width))x\(Int(uiImage.size.height)) orient=\(uiImage.imageOrientation.rawValue) → \(Int(cleaned.size.width))x\(Int(cleaned.size.height)) (\(jpegData.count / 1024)KB JPEG)")
                await MainActor.run {
                    scanSession.addPage(cleaned)
                }
            }
        }

        // Clear selection so user can pick again
        await MainActor.run {
            selectedPhotoItems = []
        }

        HapticsService.capture()
    }

    /// Force-normalizes UIImage orientation to .up by redrawing.
    /// Photos from the library often have EXIF rotation tags that Gemini may not respect.
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // 1:1 pixels, no Retina scaling
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // 1:1 pixels, no Retina scaling
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func capturePhoto() async {
        guard !isCapturing else { return }
        isCapturing = true
        HapticsService.capture()

        defer { isCapturing = false }

        if let image = await cameraService.capturePhoto() {
            await MainActor.run {
                scanSession.addPage(image)
            }
        }
    }

    private func startAnalysis() async {
        print("[LocalFlavors] startAnalysis called")
        guard let restaurant = appState.detectedRestaurant else {
            print("[LocalFlavors] No restaurant detected, opening picker")
            showRestaurantPicker = true
            showRestaurantRequired = true
            return
        }

        let imageData = scanSession.pages.compactMap { $0.jpegData(compressionQuality: 0.7) }
        print("[LocalFlavors] Image data count: \(imageData.count), sizes: \(imageData.map { "\($0.count / 1024)KB" })")
        guard !imageData.isEmpty else {
            print("[LocalFlavors] No image data!")
            return
        }

        appState.currentScreen = .analyzing
        print("[LocalFlavors] Calling analyzeMenu API...")

        do {
            let result = try await apiService.analyzeMenu(
                placeId: restaurant.id,
                restaurantName: restaurant.name,
                images: imageData
            )
            print("[LocalFlavors] Analysis complete! \(result.allDishes.count) dishes found")
            appState.analysisResult = result
            appState.currentScreen = .results
            HapticsService.success()
        } catch {
            print("[LocalFlavors] analyzeMenu ERROR: \(error)")
            appState.error = error.localizedDescription
            appState.currentScreen = .camera
            HapticsService.error()
        }
    }

    private func detectRestaurant(latitude: Double, longitude: Double) async {
        print("[LocalFlavors] detectRestaurant called: \(latitude), \(longitude)")
        do {
            let restaurant = try await apiService.detectRestaurant(latitude: latitude, longitude: longitude)
            print("[LocalFlavors] Restaurant found: \(restaurant.name)")
            appState.detectedRestaurant = restaurant
        } catch {
            print("[LocalFlavors] detectRestaurant ERROR: \(error)")
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        updatePreviewOrientation()
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer.connection else { return }
        let angle = CameraService.videoRotationAngle(for: UIDevice.current.orientation)
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }
}
