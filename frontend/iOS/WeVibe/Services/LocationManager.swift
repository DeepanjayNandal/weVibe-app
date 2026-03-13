import CoreLocation
import UIKit

/// LocationManager uses ObservableObject + @Published instead of @Observable
/// because CLLocationManagerDelegate requires NSObject inheritance, and
/// @Observable + NSObject conflict due to KVO/swizzling incompatibility.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let clManager = CLLocationManager()
    private let geocoder = CLGeocoder() // single instance — cancels previous request on reuse

    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var zip: String = ""
    @Published var isLoading: Bool = false

    /// Raw coordinate for proximity/matching use.
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0

    /// Set this from AuthManager after login to push location updates to the backend.
    /// Called on every significant location change (500 m distanceFilter) while app is active.
    var onLocationUpdated: ((_ lat: Double, _ lng: Double, _ city: String, _ state: String, _ zip: String) -> Void)?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        // Only fire delegate again after 500 m of movement — saves battery.
        clManager.distanceFilter = 500
        authStatus = clManager.authorizationStatus

        // Resume tracking on relaunch if already authorized.
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            startUpdating()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    // MARK: - Permission

    /// Called once from SurveyStep1.onAppear when status is .notDetermined.
    func requestPermission() {
        clManager.requestWhenInUseAuthorization()
    }

    // MARK: - Updates

    func startUpdating() {
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else { return }
        isLoading = city.isEmpty
        clManager.startUpdatingLocation()
    }

    func stopUpdating() {
        clManager.stopUpdatingLocation()
    }

    /// Force an immediate re-fetch without changing the ongoing tracking setup.
    /// Stops and restarts continuous updates — this always delivers a fresh fix
    /// regardless of distanceFilter, because CLLocationManager always sends one
    /// location immediately after startUpdatingLocation().
    func refreshLocation() {
        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else { return }
        isLoading = true
        clManager.stopUpdatingLocation()
        clManager.startUpdatingLocation()
    }

    // MARK: - App Lifecycle

    @objc private func appDidBecomeActive() {
        startUpdating()
    }

    @objc private func appDidEnterBackground() {
        stopUpdating()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
        geocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore kCLErrorLocationUnknown — it's transient; CLLocationManager keeps trying.
        let clError = error as? CLError
        if clError?.code == .locationUnknown { return }
        DispatchQueue.main.async { self.isLoading = false }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authStatus = manager.authorizationStatus
            if self.authStatus == .authorizedWhenInUse || self.authStatus == .authorizedAlways {
                self.startUpdating()
            } else {
                self.stopUpdating()
            }
        }
    }

    // MARK: - Geocoding

    private func geocode(_ location: CLLocation) {
        // cancelGeocode() cancels any in-flight request before starting a new one.
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let placemark = placemarks?.first {
                    self.city  = placemark.locality ?? self.city
                    self.state = placemark.administrativeArea ?? self.state
                    self.zip   = placemark.postalCode ?? self.zip
                }
                self.isLoading = false
                if !self.city.isEmpty {
                    self.onLocationUpdated?(self.latitude, self.longitude, self.city, self.state, self.zip)
                }
            }
        }
    }
}
