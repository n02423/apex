import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var location: String?
    var profileImageURL: String?
    let createdAt: Date
    var updatedAt: Date
    var preferences: UserPreferences
    var statistics: UserStatistics

    init(
        id: String = UUID().uuidString,
        name: String,
        email: String,
        location: String? = nil,
        profileImageURL: String? = nil,
        preferences: UserPreferences = UserPreferences(),
        statistics: UserStatistics = UserStatistics()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.location = location
        self.profileImageURL = profileImageURL
        self.createdAt = Date()
        self.updatedAt = Date()
        self.preferences = preferences
        self.statistics = statistics
    }

    var isAnonymous: Bool {
        id.hasPrefix("anonymous_")
    }

    var displayName: String {
        if isAnonymous {
            return "Guest User"
        }
        return name.isEmpty ? email.components(separatedBy: "@").first ?? "User" : name
    }

    var initials: String {
        let components = displayName.components(separatedBy: " ")
        return components.map { String($0.prefix(1)) }.joined()
    }
}

struct UserPreferences: Codable {
    var locationServicesEnabled: Bool
    var autoSyncEnabled: Bool
    var notificationsEnabled: Bool
    var darkModeEnabled: Bool
    var confidenceThreshold: Double // 0.0 to 1.0
    var imageQuality: ImageQuality
    var exportFormat: ExportFormat

    init(
        locationServicesEnabled: Bool = false,
        autoSyncEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        darkModeEnabled: Bool = false,
        confidenceThreshold: Double = 0.6,
        imageQuality: ImageQuality = .high,
        exportFormat: ExportFormat = .pdf
    ) {
        self.locationServicesEnabled = locationServicesEnabled
        self.autoSyncEnabled = autoSyncEnabled
        self.notificationsEnabled = notificationsEnabled
        self.darkModeEnabled = darkModeEnabled
        self.confidenceThreshold = confidenceThreshold
        self.imageQuality = imageQuality
        self.exportFormat = exportFormat
    }
}

enum ImageQuality: String, CaseIterable, Codable {
    case low = "Low (Fast)"
    case medium = "Medium"
    case high = "High (Recommended)"
    case ultra = "Ultra (Best)"

    var compressionQuality: CGFloat {
        switch self {
        case .low:
            return 0.3
        case .medium:
            return 0.6
        case .high:
            return 0.8
        case .ultra:
            return 1.0
        }
    }

    var maxFileSize: Int64 {
        switch self {
        case .low:
            return 500_000 // 500KB
        case .medium:
            return 1_000_000 // 1MB
        case .high:
            return 2_000_000 // 2MB
        case .ultra:
            return 5_000_000 // 5MB
        }
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case pdf = "PDF Report"
    case csv = "CSV Data"
    case json = "JSON"
    case image = "Image Only"

    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .csv:
            return "csv"
        case .json:
            return "json"
        case .image:
            return "jpg"
        }
    }

    var mimeType: String {
        switch self {
        case .pdf:
            return "application/pdf"
        case .csv:
            return "text/csv"
        case .json:
            return "application/json"
        case .image:
            return "image/jpeg"
        }
    }
}

struct UserStatistics: Codable {
    var totalScans: Int
    var scansThisWeek: Int
    var scansThisMonth: Int
    var mostCommonSoilType: SoilType?
    var averageConfidence: Double
    var lastScanDate: Date?
    var streakDays: Int // Consecutive days with at least one scan

    init(
        totalScans: Int = 0,
        scansThisWeek: Int = 0,
        scansThisMonth: Int = 0,
        mostCommonSoilType: SoilType? = nil,
        averageConfidence: Double = 0.0,
        lastScanDate: Date? = nil,
        streakDays: Int = 0
    ) {
        self.totalScans = totalScans
        self.scansThisWeek = scansThisWeek
        self.scansThisMonth = scansThisMonth
        self.mostCommonSoilType = mostCommonSoilType
        self.averageConfidence = averageConfidence
        self.lastScanDate = lastScanDate
        self.streakDays = streakDays
    }

    var hasScansToday: Bool {
        guard let lastScan = lastScanDate else { return false }
        return Calendar.current.isDateInToday(lastScan)
    }

    var averageConfidencePercentage: Int {
        Int(averageConfidence * 100)
    }

    mutating func updateStatistics(with results: [SoilResult]) {
        totalScans = results.count

        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        scansThisWeek = results.filter { $0.timestamp >= weekAgo }.count
        scansThisMonth = results.filter { $0.timestamp >= monthAgo }.count

        // Calculate most common soil type
        let soilTypeCounts = Dictionary(grouping: results) { $0.classificationResult }
            .mapValues { $0.count }

        mostCommonSoilType = soilTypeCounts.max(by: { $0.value < $1.value })?.key

        // Calculate average confidence
        if !results.isEmpty {
            averageConfidence = results.reduce(0) { $0 + $1.confidenceScore } / Double(results.count)
        }

        // Update last scan date
        lastScanDate = results.max(by: { $0.timestamp < $1.timestamp })?.timestamp

        // Calculate streak days (simplified - just consecutive days with scans)
        calculateStreakDays(from: results)
    }

    private mutating func calculateStreakDays(from results: [SoilResult]) {
        guard !results.isEmpty else {
            streakDays = 0
            return
        }

        let calendar = Calendar.current
        let sortedResults = results.sorted { $0.timestamp > $1.timestamp }

        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Check if there's a scan today
        if let todayScan = sortedResults.first, calendar.isDate(todayScan.timestamp, inSameDayAs: currentDate) {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        } else {
            // No scan today, check yesterday to start streak
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }

        // Count consecutive days going backwards
        while true {
            let hasScanOnDay = sortedResults.contains { result in
                calendar.isDate(result.timestamp, inSameDayAs: currentDate)
            }

            if hasScanOnDay {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }

        streakDays = streak
    }
}

// MARK: - Anonymous User Support
extension User {
    static func createAnonymousUser() -> User {
        return User(
            id: "anonymous_\(UUID().uuidString)",
            name: "",
            email: "anonymous@soilvision.local"
        )
    }

    func upgradeToFullUser(name: String, email: String) -> User {
        var updatedUser = self
        updatedUser.id = UUID().uuidString // Generate new ID for registered user
        updatedUser.name = name
        updatedUser.email = email
        updatedUser.updatedAt = Date()
        return updatedUser
    }
}

// MARK: - Validation
extension User {
    var isValid: Bool {
        !email.isEmpty && email.contains("@") && !name.isEmpty
    }

    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    static func validateName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 50
    }
}