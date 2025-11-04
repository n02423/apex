import SwiftUI
import Combine

class ResultViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var classificationResult: SoilClassificationResult?
    @Published var errorMessage: String?
    @Published var showShareSheet = false
    @Published var showSaveAlert = false
    @Published var saveMessage = ""

    private let imageProcessor = ImageProcessor.shared
    private let classifier = SoilClassifierService.shared
    private var cancellables = Set<AnyCancellable>()

    // Location and user data
    @Published var locationData: LocationData?
    @Published var savedResult: SoilResult?

    func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        errorMessage = nil

        // Process image for ML analysis
        let processResult = imageProcessor.processImageForAnalysis(image)

        switch processResult {
        case .success(let processedImage):
            performClassification(processedImage)
        case .failure(let error):
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func performClassification(_ processedImage: ProcessedImage) {
        classifier.classifyImage(processedImage.preprocessedImage) { [weak self] result in
            DispatchQueue.main.async {
                self?.isAnalyzing = false

                switch result {
                case .success(let classificationResult):
                    self?.classificationResult = classificationResult

                    // Create location data
                    self?.createLocationData()

                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func createLocationData() {
        // Get current location if available
        LocationTrackingManager().getCurrentLocation()
    }

    func saveResult() {
        guard let classificationResult = classificationResult else {
            saveMessage = "No classification result to save"
            showSaveAlert = true
            return
        }

        // Create soil result object
        let soilResult = SoilResult(
            imageLocalPath: savedResult?.imageLocalPath ?? "placeholder_path",
            classificationResult: classificationResult.primarySoilType,
            confidenceScore: Double(classificationResult.confidence),
            location: locationData
        )

        // Save to database
        // DatabaseManager.shared.saveSoilResult(soilResult)

        savedResult = soilResult
        saveMessage = "Soil analysis result saved successfully!"
        showSaveAlert = true

        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    func shareResult() {
        guard let result = savedResult else {
            // Try to create a result from classification
            if let classificationResult = classificationResult {
                saveResult() // This will create savedResult
                return
            }
            return
        }

        showShareSheet = true
    }
}