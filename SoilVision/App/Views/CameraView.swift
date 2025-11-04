import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var showResultView = false
    @State private var capturedImageForAnalysis: UIImage?
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if !cameraViewModel.isAuthorized {
                    CameraPermissionView(requestPermission: cameraViewModel.requestCameraPermission)
                } else if let errorMessage = cameraViewModel.errorMessage {
                    CameraErrorView(
                        errorMessage: errorMessage,
                        onRetry: cameraViewModel.checkCameraPermission
                    )
                } else if let capturedImage = cameraViewModel.capturedImage {
                    ImagePreviewView(
                        image: capturedImage,
                        onRetake: {
                            cameraViewModel.clearCapturedImage()
                        },
                        onAnalyze: {
                            capturedImageForAnalysis = capturedImage
                            showResultView = true
                        }
                    )
                } else {
                    CameraInterfaceView(cameraViewModel: cameraViewModel)
                }
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if cameraViewModel.capturedImage == nil {
                        Button(action: {
                            cameraViewModel.selectImageFromLibrary()
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.white)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if cameraViewModel.capturedImage == nil && cameraViewModel.captureDevice?.hasFlash == true {
                        Button(action: {
                            cameraViewModel.toggleFlash()
                        }) {
                            Image(systemName: cameraViewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .foregroundColor(cameraViewModel.isFlashOn ? .yellow : .white)
                        }
                    }
                }
            }
            .sheet(isPresented: $cameraViewModel.showImagePicker) {
                ImagePicker(selectedImage: $cameraViewModel.selectedImage)
                    .onDisappear {
                        if let selectedImage = cameraViewModel.selectedImage {
                            cameraViewModel.processSelectedImage(selectedImage)
                        }
                    }
            }
            .fullScreenCover(isPresented: $showResultView) {
                if let image = capturedImageForAnalysis {
                    ResultView(capturedImage: image) {
                        showResultView = false
                        capturedImageForAnalysis = nil
                        cameraViewModel.clearCapturedImage()
                    }
                }
            }
            .onAppear {
                cameraViewModel.startSession()
            }
            .onDisappear {
                cameraViewModel.stopSession()
            }
        }
    }
}

struct CameraInterfaceView: View {
    @ObservedObject var cameraViewModel: CameraViewModel

    var body: some View {
        ZStack {
            // Camera preview
            if let previewLayer = cameraViewModel.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .ignoresSafeArea()
            }

            // Overlay UI
            VStack {
                // Top overlay with instructions
                VStack {
                    Text("Position soil sample in frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2)
                        .padding(.top, 20)

                    Text("Ensure good lighting and clear focus")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black, radius: 2)
                }

                Spacer()

                // Frame guide
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .overlay(
                        VStack {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))

                            Text("Center soil here")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )

                Spacer()

                // Bottom controls
                HStack(spacing: 40) {
                    // Gallery button
                    Button(action: {
                        cameraViewModel.selectImageFromLibrary()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 50, height: 50)

                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }

                    // Capture button
                    Button(action: {
                        cameraViewModel.capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)

                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)

                            if cameraViewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Circle()
                                    .fill(Color.AppTheme.accentGreen)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .disabled(cameraViewModel.isProcessing)

                    // Info button
                    Button(action: {
                        // Show camera tips
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 50, height: 50)

                            Image(systemName: "info.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onAnalyze: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Preview image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .cornerRadius(10)
                    .padding()

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Text("Ready to analyze?")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("This will identify the soil type using AI")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 16) {
                        Button("Retake") {
                            onRetake()
                        }
                        .buttonStyle(SecondaryCameraButtonStyle())

                        Button("Analyze Soil") {
                            onAnalyze()
                        }
                        .buttonStyle(PrimaryCameraButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct CameraPermissionView: View {
    let requestPermission: () -> Void

    var body: some View {
        ZStack {
            Color.AppTheme.backgroundCream.ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.AppTheme.primaryBrown)

                VStack(spacing: 16) {
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    Text("SoilVision needs camera access to analyze soil samples. Your privacy is important - all processing happens on your device.")
                        .font(.body)
                        .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Enable Camera") {
                    requestPermission()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)

                Button("Not Now") {
                    // User can still use other features
                }
                .foregroundColor(.AppTheme.textDarkBrown.opacity(0.6))
            }
            .padding()
        }
    }
}

struct CameraErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color.AppTheme.backgroundCream.ignoresSafeArea()

            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.AppTheme.errorRed)

                VStack(spacing: 16) {
                    Text("Camera Error")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.AppTheme.textDarkBrown)

                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.AppTheme.textDarkBrown.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)

                Button("Use Gallery Instead") {
                    // Alternative option
                }
                .foregroundColor(.AppTheme.accentGreen)
            }
            .padding()
        }
    }
}

// MARK: - Custom Button Styles for Camera
struct PrimaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.AppTheme.accentGreen)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryCameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white.opacity(0.2))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CameraView()
        .environmentObject(LocationManager())
}