import Foundation
import SwiftUI

enum SoilType: String, CaseIterable, Codable {
    case clay = "Clay"
    case loam = "Loam"
    case sandy = "Sandy"
    case silt = "Silt"
    case peat = "Peat"
    case chalk = "Chalk"

    var description: String {
        switch self {
        case .clay:
            return "Heavy, dense soil that retains water but drains slowly"
        case .loam:
            return "Ideal balance of sand, silt, and clay - great for most plants"
        case .sandy:
            return "Light, gritty soil that drains quickly but needs frequent watering"
        case .silt:
            return "Smooth, fine soil that holds moisture well"
        case .peat:
            return "Acidic, organic soil that holds water and nutrients"
        case .chalk:
            return "Alkaline, stony soil that drains freely"
        }
    }

    var color: Color {
        switch self {
        case .clay:
            return .brown
        case .loam:
            return .green
        case .sandy:
            return .yellow
        case .silt:
            return .orange
        case .peat:
            return .black
        case .chalk:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .clay:
            return "circle.fill"
        case .loam:
            return "leaf.fill"
        case .sandy:
            case .silt:
            return "drop.fill"
        case .peat:
            return "flame.fill"
        case .chalk:
            return "mountain.2.fill"
        }
    }
}

struct SoilResult: Identifiable, Codable, Hashable {
    let id: String
    let userId: String?
    let imageLocalPath: String
    var imageURL: String?
    let classificationResult: SoilType
    let confidenceScore: Double
    let timestamp: Date
    var location: LocationData?
    var synced: Bool
    var metadata: SoilTestMetadata

    init(
        id: String = UUID().uuidString,
        userId: String? = nil,
        imageLocalPath: String,
        classificationResult: SoilType,
        confidenceScore: Double,
        location: LocationData? = nil,
        metadata: SoilTestMetadata = SoilTestMetadata()
    ) {
        self.id = id
        self.userId = userId
        self.imageLocalPath = imageLocalPath
        self.classificationResult = classificationResult
        self.confidenceScore = confidenceScore
        self.timestamp = Date()
        self.location = location
        self.synced = false
        self.metadata = metadata
    }

    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }

    var confidenceLevel: String {
        switch confidenceScore {
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

    var isHighConfidence: Bool {
        confidenceScore >= 0.60
    }
}

struct SoilTestMetadata: Codable, Hashable {
    let deviceInfo: String
    let appVersion: String
    let imageMetadata: ImageMetadata?

    init(
        deviceInfo: String = UIDevice.current.model,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        imageMetadata: ImageMetadata? = nil
    ) {
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
        self.imageMetadata = imageMetadata
    }
}

struct ImageMetadata: Codable, Hashable {
    let width: Int
    let height: Int
    let fileSize: Int64
    let format: String
    let captureDate: Date?

    init(width: Int, height: Int, fileSize: Int64, format: String, captureDate: Date? = nil) {
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.format = format
        self.captureDate = captureDate
    }
}

// MARK: - Convenience Extensions
extension SoilResult {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    func exportAsCSV() -> String {
        let csvString = """
        ID,Date,Soil Type,Confidence,Confidence %,Latitude,Longitude,Accuracy,Synced
        \(id),\(formattedDate),\(classificationResult.rawValue),\(confidenceScore),\(confidencePercentage)%,\(location?.latitude ?? 0),\(location?.longitude ?? 0),\(location?.accuracy ?? 0),\(synced)
        """
        return csvString
    }

    func exportAsPDFData() -> Data {
        let pdfData = NSMutableData()

        let rect = CGRect(x: 0, y: 0, width: 612, height: 792) // Standard letter size
        UIGraphicsBeginPDFContextToData(pdfData, rect, nil)
        UIGraphicsBeginPDFPage()

        let context = UIGraphicsGetCurrentContext()

        // Title
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let titleText = "Soil Analysis Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        titleText.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

        // Date
        let dateFont = UIFont.systemFont(ofSize: 14)
        let dateText = "Date: \(formattedDate)"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: UIColor.darkGray
        ]
        dateText.draw(at: CGPoint(x: 50, y: 90), withAttributes: dateAttributes)

        // Classification Result
        let resultFont = UIFont.boldSystemFont(ofSize: 18)
        let resultText = "Soil Type: \(classificationResult.rawValue)"
        let resultAttributes: [NSAttributedString.Key: Any] = [
            .font: resultFont,
            .foregroundColor: UIColor.black
        ]
        resultText.draw(at: CGPoint(x: 50, y: 120), withAttributes: resultAttributes)

        // Confidence
        let confidenceText = "Confidence: \(confidencePercentage)% (\(confidenceLevel))"
        confidenceText.draw(at: CGPoint(x: 50, y: 150), withAttributes: dateAttributes)

        // Location (if available)
        if let location = location {
            let locationText = "Location: \(location.latitude), \(location.longitude) (±\(location.accuracy)m)"
            locationText.draw(at: CGPoint(x: 50, y: 180), withAttributes: dateAttributes)
        }

        // Description
        let descriptionFont = UIFont.systemFont(ofSize: 16)
        let descriptionText = "Description: \(classificationResult.description)"
        let descriptionAttributes: [NSAttributedString.Key: Any] = [
            .font: descriptionFont,
            .foregroundColor: UIColor.black
        ]
        let descriptionRect = CGRect(x: 50, y: 220, width: 512, height: 100)
        descriptionText.draw(in: descriptionRect, withAttributes: descriptionAttributes)

        UIGraphicsEndPDFContext()

        return pdfData as Data
    }
}