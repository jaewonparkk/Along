import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    private let manager = CLLocationManager()

    override init() {

        authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {

        switch manager.authorizationStatus {

        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedAlways,
             .authorizedWhenInUse:
            manager.startUpdatingLocation()

        case .denied,
             .restricted:
            break

        @unknown default:
            break
        }
    }
}


// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        DispatchQueue.main.async {

            self.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {

            case .authorizedAlways,
                 .authorizedWhenInUse:

                manager.startUpdatingLocation()

            default:
                break
            }
        }
    }


    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let location = locations.last else {
            return
        }

        DispatchQueue.main.async {
            self.lastLocation = location
        }

        manager.stopUpdatingLocation()
    }


    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        print(
            "Location error:",
            error.localizedDescription
        )
    }
}
