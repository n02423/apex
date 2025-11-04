import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: LocationData?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = AppConstants.Location.desiredAccuracy
        locationManager.distanceFilter = AppConstants.Location.distanceFilter
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
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
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            errorMessage = "Location permission not granted"
            return
        }

        locationManager.requestLocation()
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Filter out old or inaccurate locations
        let locationAge = -location.timestamp.timeIntervalSinceNow
        if locationAge > 5.0 { // Location is older than 5 seconds
            return
        }

        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 { // Poor accuracy
            return
        }

        let locationData = LocationData(from: location)
        currentLocation = locationData

        // Stop tracking after getting one location if not continuously tracking
        if !isTracking {
            locationManager.stopUpdatingLocation()
        }

        print("Location updated: \(locationData.formattedCoordinates)")
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
        print("Location error: \(error.localizedDescription)")

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location permission was denied"
            case .locationUnknown:
                errorMessage = "Unable to determine location"
            case .network:
                errorMessage = "Network error occurred"
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("Location permission granted")
                if self.isTracking {
                    self.startTracking()
                }
            case .denied, .restricted:
                print("Location permission denied")
                self.errorMessage = "Location permission was denied"
            case .notDetermined:
                print("Location permission not determined")
            @unknown default:
                print("Unknown authorization status")
            }
        }
    }
}