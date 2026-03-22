import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraReady = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    // MARK: - Session Setup

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }

        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        session.commitConfiguration()

        DispatchQueue.main.async {
            self.isCameraReady = true
        }
    }

    // MARK: - Session Control

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()

            // Set correct orientation so captured photo matches what user sees
            if let connection = photoOutput.connection(with: .video) {
                let angle = Self.videoRotationAngle(for: UIDevice.current.orientation)
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Maps UIDeviceOrientation to AVCaptureConnection videoRotationAngle (degrees).
    /// Note: UIDevice and AVCapture use inverted left/right conventions.
    static func videoRotationAngle(for deviceOrientation: UIDeviceOrientation) -> CGFloat {
        switch deviceOrientation {
        case .landscapeLeft:  return 0     // Home button right → landscape right in camera terms
        case .landscapeRight: return 180   // Home button left → landscape left in camera terms
        case .portraitUpsideDown: return 270
        default: return 90                 // Portrait (default)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { continuation = nil }

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(returning: nil)
            return
        }

        // Resize for upload (max 2400px longest edge — needed for dense menus with many small items)
        let resized = resizeImage(image, maxWidth: 2400)
        continuation?.resume(returning: resized)
    }

    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        // Scale based on the LONGEST edge (works for both portrait and landscape)
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxWidth else { return image }
        let scale = maxWidth / longestEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Force scale 1.0 so we get actual pixels, not points × deviceScale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
