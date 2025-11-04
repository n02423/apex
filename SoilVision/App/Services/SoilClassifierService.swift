import Foundation
import CoreML
import Vision
import UIKit
import Combine

class SoilClassifierService: ObservableObject {
    static let shared = SoilClassifierService()

    @Published var isModelLoaded = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var visionModel: VNCoreMLModel?
    private let confidenceThreshold: Double = AppConstants.ML.confidenceThreshold

    private init() {
        loadModel()
    }

    // MARK: - Model Loading
    private func loadModel() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Try to load the CoreML model
                guard let modelURL = Bundle.main.url(forResource: "SoilClassifier", withExtension: "mlmodel") else {
                    throw ClassificationError.modelNotFound
                }

                // Compile the model
                let compiledModelURL = try MLModel.compileModel(at: modelURL)
                let mlModel = try MLModel(contentsOf: compiledModelURL)

                // Create Vision model
                self?.visionModel = try VNCoreMLModel(for: mlModel)

                DispatchQueue.main.async {
                    self?.isModelLoaded = true
                    self?.isLoading = false
                    print("✅ Soil classification model loaded successfully")
                }

            } catch {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Failed to load ML model: \(error.localizedDescription)"
                    print("❌ Error loading ML model: \(error)")
                }
            }
        }
    }

    // MARK: - Classification
    func classifyImage(_ image: UIImage, completion: @escaping (Result<SoilClassificationResult, Error>) -> Void) {
        guard isModelLoaded else {
            completion(.failure(ClassificationError.modelNotLoaded))
            return
        }

        guard let cgImage = image.cgImage else {
            completion(.failure(ClassificationError.invalidImage))
            return
        }

        // Perform classification on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performClassification(on: cgImage, completion: completion)
        }
    }

    private func performClassification(on cgImage: CGImage, completion: @escaping (Result<SoilClassificationResult, Error>) -> Void) {
        let request = VNCoreMLRequest(model: visionModel!) { [weak self] request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(ClassificationError.classificationFailed(error.localizedDescription)))
                }
                return
            }

            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                DispatchQueue.main.async {
                    completion(.failure(ClassificationError.noResults))
                }
                return
            }

            // Process results
            let classificationResult = self?.processClassificationResults(results)

            DispatchQueue.main.async {
                if let result = classificationResult {
                    completion(.success(result))
                } else {
                    completion(.failure(ClassificationError.lowConfidence))
                }
            }
        }

        // Configure request
        request.imageCropAndScaleOption = .centerCrop

        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async {
                completion(.failure(ClassificationError.classificationFailed(error.localizedDescription)))
            }
        }
    }

    private func processClassificationResults(_ results: [VNClassificationObservation]) -> SoilClassificationResult? {
        // Filter results by confidence threshold
        let validResults = results.filter { $0.confidence >= confidenceThreshold }

        guard let topResult = validResults.first else {
            return nil
        }

        // Map Vision labels to our SoilType enum
        guard let soilType = mapVisionLabelToSoilType(topResult.identifier) else {
            print("⚠️ Unknown soil type: \(topResult.identifier)")
            return nil
        }

        // Calculate confidence percentages
        let allProbabilities = results.prefix(6).map { result in
            SoilClassificationProbability(
                soilType: mapVisionLabelToSoilType(result.identifier) ?? .clay,
                confidence: result.confidence,
                percentage: Int(result.confidence * 100)
            )
        }

        return SoilClassificationResult(
            primarySoilType: soilType,
            confidence: topResult.confidence,
            confidencePercentage: Int(topResult.confidence * 100),
            confidenceLevel: determineConfidenceLevel(topResult.confidence),
            allProbabilities: allProbabilities,
            processingTime: 0.0 // Would be measured in real implementation
        )
    }

    private func mapVisionLabelToSoilType(_ identifier: String) -> SoilType? {
        // Clean up the identifier (remove spaces, convert to lowercase)
        let cleanedIdentifier = identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        switch cleanedIdentifier {
        case "clay":
            return .clay
        case "loam":
            return .loam
        case "sandy", "sand":
            return .sandy
        case "silt":
            return .silt
        case "peat":
            return .peat
        case "chalk", "limestone":
            return .chalk
        default:
            // Try fuzzy matching
            if cleanedIdentifier.contains("clay") {
                return .clay
            } else if cleanedIdentifier.contains("loam") {
                return .loam
            } else if cleanedIdentifier.contains("sand") {
                return .sandy
            } else if cleanedIdentifier.contains("silt") {
                return .silt
            } else if cleanedIdentifier.contains("peat") {
                return .peat
            } else if cleanedIdentifier.contains("chalk") {
                return .chalk
            }
            return nil
        }
    }

    private func determineConfidenceLevel(_ confidence: Float) -> String {
        switch confidence {
        case 0.90...1.0:
            return "Very High"
        case 0.75..<0.90:
            return "High"
        case 0.60..<0.75:
            return "Medium"
        case 0.40..<0.60:
            return "Low"
        default:
            return "Very Low"
        }
    }

    // MARK: - Batch Classification
    func classifyImages(_ images: [UIImage], completion: @escaping (Result<[SoilClassificationResult], Error>) -> Void) {
        var results: [SoilClassificationResult] = []
        var errors: [Error] = []
        let dispatchGroup = DispatchGroup()

        for (index, image) in images.enumerated() {
            dispatchGroup.enter()

            classifyImage(image) { result in
                switch result {
                case .success(let classificationResult):
                    // Ensure results are in the same order as input images
                    if index < results.count {
                        results[index] = classificationResult
                    } else {
                        // Resize array if needed
                        while results.count <= index {
                            results.append(classificationResult) // Placeholder
                        }
                        results[index] = classificationResult
                    }
                case .failure(let error):
                    errors.append(error)
                }

                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty && !results.isEmpty {
                completion(.success(results))
            } else if let firstError = errors.first {
                completion(.failure(firstError))
            } else {
                completion(.failure(ClassificationError.noResults))
            }
        }
    }

    // MARK: - Model Information
    func getModelInfo() -> ModelInfo {
        return ModelInfo(
            name: "SoilClassifier",
            version: "1.0.0",
            description: "CNN-based soil type classification model",
            supportedClasses: SoilType.allCases,
            inputSize: CGSize(width: 224, height: 224),
            confidenceThreshold: confidenceThreshold,
            isLoaded: isModelLoaded
        )
    }

    // MARK: - Performance Monitoring
    func measurePerformance(_ image: UIImage, iterations: Int = 10, completion: @escaping (PerformanceMetrics) -> Void) {
        guard isModelLoaded else {
            completion(PerformanceMetrics(averageTime: 0, minTime: 0, maxTime: 0, iterations: 0))
            return
        }

        var times: [TimeInterval] = []
        let dispatchGroup = DispatchGroup()

        for _ in 0..<iterations {
            dispatchGroup.enter()

            let startTime = CFAbsoluteTimeGetCurrent()

            classifyImage(image) { _ in
                let endTime = CFAbsoluteTimeGetCurrent()
                times.append(endTime - startTime)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            let averageTime = times.reduce(0, +) / Double(times.count)
            let minTime = times.min() ?? 0
            let maxTime = times.max() ?? 0

            let metrics = PerformanceMetrics(
                averageTime: averageTime,
                minTime: minTime,
                maxTime: maxTime,
                iterations: iterations
            )

            completion(metrics)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Supporting Types
struct SoilClassificationResult {
    let primarySoilType: SoilType
    let confidence: Float
    let confidencePercentage: Int
    let confidenceLevel: String
    let allProbabilities: [SoilClassificationProbability]
    let processingTime: TimeInterval

    var isHighConfidence: Bool {
        confidence >= 0.6
    }

    var isVeryHighConfidence: Bool {
        confidence >= 0.9
    }
}

struct SoilClassificationProbability {
    let soilType: SoilType
    let confidence: Float
    let percentage: Int
}

struct ModelInfo {
    let name: String
    let version: String
    let description: String
    let supportedClasses: [SoilType]
    let inputSize: CGSize
    let confidenceThreshold: Double
    let isLoaded: Bool
}

struct PerformanceMetrics {
    let averageTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let iterations: Int

    var averageTimeString: String {
        return String(format: "%.3f seconds", averageTime * 1000)
    }

    var fps: Double {
        return 1.0 / averageTime
    }
}

enum ClassificationError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case invalidImage
    case classificationFailed(String)
    case noResults
    case lowConfidence

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Soil classification model not found. Please ensure the model file is included in the app bundle."
        case .modelNotLoaded:
            return "Soil classification model is not loaded yet. Please wait and try again."
        case .invalidImage:
            return "The provided image is invalid or corrupted."
        case .classificationFailed(let reason):
            return "Classification failed: \(reason)"
        case .noResults:
            return "No classification results were returned."
        case .lowConfidence:
            return "The model is not confident enough in any prediction. Please try with a clearer image."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .modelNotFound:
            return "Please reinstall the app or contact support."
        case .modelNotLoaded:
            return "Please wait a moment and try again."
        case .invalidImage:
            return "Please use a valid image file."
        case .classificationFailed:
            return "Please try again with a different image."
        case .noResults:
            return "Please ensure the image contains visible soil and try again."
        case .lowConfidence:
            return "Try taking a clearer photo with better lighting and focus."
        }
    }
}