import Foundation
import CoreLocation
import MapKit

struct LocationData: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let altitude: Double?
    let speed: Double?
    let course: Double?

    init(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        timestamp: Date = Date(),
        altitude: Double? = nil,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.altitude = altitude
        self.speed = speed
        self.course = course
    }

    init(from clLocation: CLLocation) {
        self.latitude = clLocation.coordinate.latitude
        self.longitude = clLocation.coordinate.longitude
        self.accuracy = clLocation.horizontalAccuracy
        self.timestamp = clLocation.timestamp
        self.altitude = clLocation.altitude
        self.speed = clLocation.speed
        self.course = clLocation.course
    }

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValid: Bool {
        // Check if coordinates are valid
        let latRange = -90.0...90.0
        let lonRange = -180.0...180.0

        return latRange.contains(latitude) &&
               lonRange.contains(longitude) &&
               accuracy >= 0 &&
               accuracy < 1000 // Reasonable accuracy threshold
    }

    var isHighAccuracy: Bool {
        accuracy <= 50.0 // Within 50 meters
    }

    var isMediumAccuracy: Bool {
        accuracy > 50.0 && accuracy <= 100.0 // 50-100 meters
    }

    var accuracyDescription: String {
        if accuracy <= 10 {
            return "Excellent (±\(Int(accuracy))m)"
        } else if accuracy <= 50 {
            return "Good (±\(Int(accuracy))m)"
        } else if accuracy <= 100 {
            return "Fair (±\(Int(accuracy))m)"
        } else {
            return "Poor (±\(Int(accuracy))m)"
        }
    }

    var formattedCoordinates: String {
        return String(format: "%.6f°, %.6f°", latitude, longitude)
    }

    var decimalDegrees: String {
        return String(format: "%.4f°, %.4f°", latitude, longitude)
    }

    var degreesMinutesSeconds: String {
        func convertToDMS(_ degrees: Double, isLatitude: Bool) -> String {
            let absolute = abs(degrees)
            let degrees = Int(absolute)
            let minutesDecimal = (absolute - Double(degrees)) * 60
            let minutes = Int(minutesDecimal)
            let seconds = (minutesDecimal - Double(minutes)) * 60

            let direction: String
            if isLatitude {
                direction = degrees >= 0 ? "N" : "S"
            } else {
                direction = degrees >= 0 ? "E" : "W"
            }

            return String(format: "%d°%d'%.1f\"%@", degrees, minutes, seconds, direction)
        }

        let latDMS = convertToDMS(latitude, isLatitude: true)
        let lonDMS = convertToDMS(longitude, isLatitude: false)

        return "\(latDMS), \(lonDMS)"
    }

    // MARK: - Distance Calculations
    func distance(to otherLocation: LocationData) -> CLLocationDistance {
        let thisLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: otherLocation.latitude, longitude: otherLocation.longitude)
        return thisLocation.distance(from: otherLocation)
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let thisLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return thisLocation.distance(from: otherLocation)
    }

    // MARK: - Map URLs
    var appleMapsURL: URL? {
        return URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)")
    }

    var googleMapsURL: URL? {
        return URL(string: "https://maps.google.com/?q=\(latitude),\(longitude)")
    }

    // MARK: - Geocoding Support
    func geocode(completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)

        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                guard let placemark = placemarks?.first else {
                    completion(nil)
                    return
                }

                let address = [
                    placemark.subThoroughfare,
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ].compactMap { $0 }.joined(separator: ", ")

                completion(address.isEmpty ? nil : address)
            }
        }
    }

    // MARK: - Location Categories
    enum LocationCategory: String, CaseIterable {
        case urban = "Urban"
        case suburban = "Suburban"
        case rural = "Rural"
        case agricultural = "Agricultural"
        case forest = "Forest"
        case coastal = "Coastal"
        case mountain = "Mountain"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .urban:
                return "building.2.fill"
            case .suburban:
                return "house.fill"
            case .rural:
                return "tree.fill"
            case .agricultural:
                return "leaf.fill"
            case .forest:
                return "tree.fill"
            case .coastal:
                return "water.waves"
            case .mountain:
                return "mountain.2.fill"
            case .unknown:
                return "location.fill"
            }
        }
    }

    func estimateLocationCategory() -> LocationCategory {
        // This is a simplified categorization based on population density
        // In a real app, you would use a reverse geocoding service
        // or land use data for more accurate categorization

        // For demonstration purposes, we'll use some heuristics
        // based on coordinate ranges (this is NOT accurate for production)

        let lat = abs(latitude)
        let lon = abs(longitude)

        // Very rough heuristics - replace with actual geocoding in production
        if lat > 40 && lat < 50 && lon > -75 && lon < -70 {
            return .urban // Example: Northeast US urban area
        } else if lat > 30 && lat < 40 && lon > -120 && lon < -110 {
            return .mountain // Example: Mountain West US
        } else if lat > 25 && lat < 35 && lon > -120 && lon < -115 {
            return .coastal // Example: West Coast US
        } else if (lat > 35 && lat < 45) && (lon > -90 && lon < -80) {
            return .agricultural // Example: Midwest US
        } else {
            return .unknown
        }
    }

    // MARK: - JSON Export
    var toJSON: [String: Any] {
        return [
            "latitude": latitude,
            "longitude": longitude,
            "accuracy": accuracy,
            "timestamp": timestamp.timeIntervalSince1970,
            "altitude": altitude as Any,
            "speed": speed as Any,
            "course": course as Any,
            "formattedCoordinates": formattedCoordinates,
            "accuracyDescription": accuracyDescription,
            "locationCategory": estimateLocationCategory().rawValue
        ]
    }
}

// MARK: - Location Utilities
extension LocationData {
    static func calculateRegion encompassing(locations: [LocationData]) -> MKCoordinateRegion? {
        guard !locations.isEmpty else { return nil }

        let minLat = locations.map(\.latitude).min()!
        let maxLat = locations.map(\.latitude).max()!
        let minLon = locations.map(\.longitude).min()!
        let maxLon = locations.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2, // Add 20% padding
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Location Tracking
class LocationTrackingManager: ObservableObject {
    @Published var currentLocation: LocationData?
    @Published var isTracking = false
    @Published var trackingError: Error?

    private let locationManager = CLLocationManager()

    init() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }

        isTracking = true
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
    }

    func getCurrentLocation() {
        locationManager.requestLocation()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationTrackingManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let locationData = LocationData(from: location)
        currentLocation = locationData

        // Stop tracking after getting one location if not continuously tracking
        if !isTracking {
            locationManager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        trackingError = error
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                startTracking()
            }
        case .denied, .restricted:
            trackingError = LocationError.permissionDenied
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission was denied. Please enable it in Settings."
        case .locationUnavailable:
            return "Unable to determine your current location."
        case .timeout:
            return "Location request timed out. Please try again."
        }
    }
}