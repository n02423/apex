import SwiftUI
import AVFoundation
import Combine
import PhotosUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var captureSession: AVCaptureSession?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isFlashOn = false
    @Published var capturedImage: UIImage?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var selectedImage: UIImage?

    private let captureSessionQueue = DispatchQueue(label: "camera.capture.session")
    private var photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?

    override init() {
        super.init()
        checkCameraPermission()
    }

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            isAuthorized = false
            errorMessage = "Camera access is required to use this feature. Please enable it in Settings."
        @unknown default:
            isAuthorized = false
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.setupCamera()
                } else {
                    self?.errorMessage = "Camera permission was denied"
                }
            }
        }
    }

    private func setupCamera() {
        captureSessionQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.sessionPreset = .photo

            do {
                // Find the best camera device
                let videoDevice = self.findBestCamera()
                guard let videoDevice = videoDevice else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "No camera device available"
                    }
                    return
                }

                self.captureDevice = videoDevice

                // Create device input
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)

                // Add input to session
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Could not add camera input to session"
                    }
                    return
                }

                // Add photo output
                if session.canAddOutput(self.photoOutput) {
                    session.addOutput(self.photoOutput)
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Could not add photo output to session"
                    }
                    return
                }

                // Setup preview layer
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill

                DispatchQueue.main.async {
                    self.previewLayer = previewLayer
                    self.captureSession = session
                }

                // Start session
                session.startRunning()

            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = "Camera setup failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func findBestCamera() -> AVCaptureDevice? {
        // Try to find the back camera first (wide angle)
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }

        // Fall back to any available camera
        if let device = AVCaptureDevice.default(for: .video) {
            return device
        }

        return nil
    }

    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }
        captureSessionQueue.async {
            session.startRunning()
        }
    }

    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }
        captureSessionQueue.async {
            session.stopRunning()
        }
    }

    func capturePhoto() {
        guard let session = captureSession, session.isRunning else {
            errorMessage = "Camera is not ready"
            return
        }

        let settings = AVCapturePhotoSettings()

        // Configure flash
        if captureDevice?.hasFlash == true {
            settings.flashMode = isFlashOn ? .on : .off
        }

        // Set high quality settings
        settings.isHighResolutionPhotoEnabled = true

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() {
        guard let device = captureDevice, device.hasFlash else { return }

        do {
            try device.lockForConfiguration()
            device.flashMode = isFlashOn ? .off : .on
            isFlashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            errorMessage = "Failed to toggle flash: \(error.localizedDescription)"
        }
    }

    func selectImageFromLibrary() {
        showImagePicker = true
    }

    func processSelectedImage(_ image: UIImage) {
        selectedImage = image
        capturedImage = image
    }

    func clearCapturedImage() {
        capturedImage = nil
        selectedImage = nil
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    // Helper method to get the correct orientation for captured images
    private func imageOrientation(from devicePosition: AVCaptureDevice.Position) -> UIImage.Orientation {
        switch devicePosition {
        case .front:
            return .leftMirrored
        case .back:
            return .right
        default:
            return .up
        }
    }

    deinit {
        stopSession()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = "Photo capture failed: \(error.localizedDescription)"
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to process captured image"
            }
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = image
            self.isProcessing = false

            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        DispatchQueue.main.async {
            self.isProcessing = true
        }
    }
}

// MARK: - Image Picker Integration
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)

        if let previewLayer = previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}