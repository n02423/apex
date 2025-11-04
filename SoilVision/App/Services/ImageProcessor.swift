import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

class ImageProcessor: ObservableObject {
    static let shared = ImageProcessor()

    private let context = CIContext()
    private let targetSize = CGSize(width: 224, height: 224) // ML model input size

    private init() {}

    // MARK: - Main Processing Pipeline
    func processImageForAnalysis(_ image: UIImage, quality: ImageQuality = .high) -> ProcessedImageResult {
        do {
            // Step 1: Validate input image
            guard validateImage(image) else {
                return .failure(ImageProcessingError.invalidImage)
            }

            // Step 2: Preprocess for ML model
            let preprocessedImage = try preprocessForML(image)

            // Step 3: Generate display image with enhancements
            let displayImage = try enhanceForDisplay(image)

            // Step 4: Save image to local storage
            let localPath = try saveImageLocally(preprocessedImage, quality: quality)

            // Step 5: Extract image metadata
            let metadata = extractImageMetadata(from: image)

            return .success(ProcessedImage(
                originalImage: image,
                preprocessedImage: preprocessedImage,
                displayImage: displayImage,
                localPath: localPath,
                metadata: metadata
            ))

        } catch {
            return .failure(error as? ImageProcessingError ?? .processingFailed(error.localizedDescription))
        }
    }

    // MARK: - Validation
    private func validateImage(_ image: UIImage) -> Bool {
        // Check if image exists
        guard image.cgImage != nil else { return false }

        // Check minimum size
        let size = image.size
        guard size.width >= 100 && size.height >= 100 else { return false }

        // Check if image is too large (prevent memory issues)
        let maxDimension: CGFloat = 4000
        guard size.width <= maxDimension && size.height <= maxDimension else { return false }

        return true
    }

    // MARK: - ML Model Preprocessing
    private func preprocessForML(_ image: UIImage) throws -> UIImage {
        // Convert to CIImage
        guard let ciImage = CIImage(image: image) else {
            throw ImageProcessingError.conversionFailed
        }

        // Step 1: Resize to target size (224x224)
        let resizedImage = resizeImage(ciImage, to: targetSize)

        // Step 2: Normalize colors (0-1 range)
        let normalizedImage = normalizeColors(resizedImage)

        // Step 3: Apply contrast enhancement for better feature extraction
        let enhancedImage = applyContrastEnhancement(normalizedImage)

        // Step 4: Convert back to UIImage
        guard let cgImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            throw ImageProcessingError.conversionFailed
        }

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: image.imageOrientation)
    }

    // MARK: - Display Enhancement
    private func enhanceForDisplay(_ image: UIImage) throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImageProcessingError.conversionFailed
        }

        // Apply subtle enhancements for better user viewing
        var enhancedImage = ciImage

        // 1. Auto-enhance
        enhancedImage = autoEnhanceImage(enhancedImage)

        // 2. Slight sharpening for better soil texture visibility
        enhancedImage = applySharpening(enhancedImage)

        // 3. Adjust exposure if needed
        enhancedImage = adjustExposure(enhancedImage)

        // Convert back to UIImage
        guard let cgImage = context.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            throw ImageProcessingError.conversionFailed
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Image Processing Operations
    private func resizeImage(_ image: CIImage, to size: CGSize) -> CIImage {
        let scale = min(size.width / image.extent.width, size.height / image.extent.height)
        let scaledSize = CGSize(width: image.extent.width * scale, height: image.extent.height * scale)

        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        filter.aspectRatio = 1.0

        let resized = filter.outputImage!

        // Crop to exact size if needed
        if resized.extent.width > size.width || resized.extent.height > size.height {
            let cropRect = CGRect(
                x: (resized.extent.width - size.width) / 2,
                y: (resized.extent.height - size.height) / 2,
                width: size.width,
                height: size.height
            )
            return resized.cropped(to: cropRect)
        }

        return resized
    }

    private func normalizeColors(_ image: CIImage) -> CIImage {
        // Apply gamma correction and color normalization
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.brightness = 0.0
        filter.contrast = 1.0
        filter.saturation = 1.0
        return filter.outputImage!
    }

    private func applyContrastEnhancement(_ image: CIImage) -> CIImage {
        // Enhance contrast to bring out soil features
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = 1.2
        filter.saturation = 1.1
        return filter.outputImage!
    }

    private func autoEnhanceImage(_ image: CIImage) -> CIImage {
        let filter = CIFilter.autoEnhancement()
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    private func applySharpening(_ image: CIImage) -> CIImage {
        let filter = CIFilter.sharpenLuminance()
        filter.inputImage = image
        filter.sharpness = 0.4
        return filter.outputImage!
    }

    private func adjustExposure(_ image: CIImage) -> CIImage {
        // Check if image is too dark or too bright and adjust
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = image

        // Calculate average brightness (simplified)
        let extent = image.extent
        let inputExtent = CIVector(cgRect: extent)
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = image
        averageFilter.inputExtent = inputExtent

        if let averageImage = averageFilter.outputImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(averageImage,
                          toBitmap: &bitmap,
                          rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: .RGBA8,
                          colorSpace: nil)

            let brightness = Double(bitmap[0]) / 255.0

            // Adjust exposure based on brightness
            if brightness < 0.3 {
                filter.ev = 0.3 // Increase exposure for dark images
            } else if brightness > 0.8 {
                filter.ev = -0.2 // Decrease exposure for bright images
            } else {
                filter.ev = 0.0 // No adjustment needed
            }
        }

        return filter.outputImage!
    }

    // MARK: - Local Storage
    private func saveImageLocally(_ image: UIImage, quality: ImageQuality) throws -> String {
        guard let data = image.jpegData(compressionQuality: quality.compressionQuality) else {
            throw ImageProcessingError.saveFailed
        }

        // Check file size
        if data.count > quality.maxFileSize {
            throw ImageProcessingError.fileTooLarge
        }

        // Create unique filename
        let filename = "soil_analysis_\(Date().timeIntervalSince1970).jpg"

        // Get documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ImageProcessingError.saveFailed
        }

        // Create app-specific directory if it doesn't exist
        let appDirectory = documentsURL.appendingPathComponent("SoilVision/Images")
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        // Save file
        let fileURL = appDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL.path
    }

    // MARK: - Metadata Extraction
    private func extractImageMetadata(from image: UIImage) -> ImageMetadata {
        return ImageMetadata(
            width: Int(image.size.width),
            height: Int(image.size.height),
            fileSize: estimateImageSize(image),
            format: "JPEG",
            captureDate: Date()
        )
    }

    private func estimateImageSize(_ image: UIImage) -> Int64 {
        // Estimate file size based on image dimensions
        let pixels = image.size.width * image.size.height
        return Int64(pixels * 3) // Rough estimate (3 bytes per pixel for RGB)
    }

    // MARK: - Batch Processing
    func processImageBatch(_ images: [UIImage], quality: ImageQuality = .medium) -> [ProcessedImageResult] {
        return images.map { processImageForAnalysis($0, quality: quality) }
    }

    // MARK: - Cleanup
    func cleanupOldImages(olderThan days: Int = 30) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let appDirectory = documentsURL.appendingPathComponent("SoilVision/Images")
        let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))

        do {
            let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: [.creationDateKey])

            for fileURL in files {
                let attributes = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = attributes.creationDate, creationDate < cutoffDate {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Error cleaning up old images: \(error)")
        }
    }

    // MARK: - Image Analysis
    func analyzeImageQuality(_ image: UIImage) -> ImageQualityAnalysis {
        guard let ciImage = CIImage(image: image) else {
            return ImageQualityAnalysis(isAcceptable: false, issues: [.invalidImage])
        }

        var issues: [ImageQualityIssue] = []
        var score: Double = 100.0

        // Check resolution
        let size = image.size
        if size.width < 300 || size.height < 300 {
            issues.append(.lowResolution)
            score -= 30
        }

        // Check brightness
        let extent = ciImage.extent
        let inputExtent = CIVector(cgRect: extent)
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = ciImage
        averageFilter.inputExtent = inputExtent

        if let averageImage = averageFilter.outputImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(averageImage,
                          toBitmap: &bitmap,
                          rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: .RGBA8,
                          colorSpace: nil)

            let brightness = Double(bitmap[0]) / 255.0

            if brightness < 0.2 {
                issues.append(.tooDark)
                score -= 25
            } else if brightness > 0.9 {
                issues.append(.tooBright)
                score -= 20
            }
        }

        // Check for blur (simplified)
        let blurScore = calculateBlurScore(ciImage)
        if blurScore < 50 {
            issues.append(.blurry)
            score -= 35
        }

        return ImageQualityAnalysis(
            isAcceptable: score >= 60,
            qualityScore: score,
            issues: issues
        )
    }

    private func calculateBlurScore(_ image: CIImage) -> Double {
        // Simplified blur detection using edge detection
        let filter = CIFilter.edges()
        filter.inputImage = image

        guard let outputImage = filter.outputImage else { return 0 }

        // Calculate edge density (higher = less blur)
        let extent = outputImage.extent
        let inputExtent = CIVector(cgRect: extent)
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = outputImage
        averageFilter.inputExtent = inputExtent

        if let averageImage = averageFilter.outputImage {
            var bitmap = [UInt8](repeating: 0, count: 4)
            context.render(averageImage,
                          toBitmap: &bitmap,
                          rowBytes: 4,
                          bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                          format: .RGBA8,
                          colorSpace: nil)

            return Double(bitmap[0]) / 255.0 * 100
        }

        return 0
    }
}

// MARK: - Supporting Types
struct ProcessedImage {
    let originalImage: UIImage
    let preprocessedImage: UIImage  // For ML model
    let displayImage: UIImage       // For user display
    let localPath: String
    let metadata: ImageMetadata
}

enum ProcessedImageResult {
    case success(ProcessedImage)
    case failure(Error)
}

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case conversionFailed
    case processingFailed(String)
    case saveFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid or corrupted"
        case .conversionFailed:
            return "Failed to convert image format"
        case .processingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .saveFailed:
            return "Failed to save image to device storage"
        case .fileTooLarge:
            return "Image file is too large to process"
        }
    }
}

struct ImageQualityAnalysis {
    let isAcceptable: Bool
    let qualityScore: Double
    let issues: [ImageQualityIssue]

    init(isAcceptable: Bool, qualityScore: Double = 0, issues: [ImageQualityIssue] = []) {
        self.isAcceptable = isAcceptable
        self.qualityScore = qualityScore
        self.issues = issues
    }
}

enum ImageQualityIssue: String, CaseIterable {
    case invalidImage = "Invalid image format"
    case lowResolution = "Image resolution too low"
    case tooDark = "Image too dark"
    case tooBright = "Image too bright"
    case blurry = "Image appears blurry"

    var suggestion: String {
        switch self {
        case .invalidImage:
            return "Please use a valid image file"
        case .lowResolution:
            return "Use a higher resolution image (minimum 300x300)"
        case .tooDark:
            return "Take photo in better lighting conditions"
        case .tooBright:
            return "Reduce lighting or adjust camera exposure"
        case .blurry:
            return "Keep camera steady and ensure good focus"
        }
    }
}