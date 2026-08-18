import Foundation
import SwiftData
import MapKit
import CoreLocation

@Model
final class SavedPlace {
    @Attribute(.unique) var placeKey: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var categoryRawValue: String
    var savedAt: Date

    init(
        place: PlannedPlace,
        category: FlexibleStopCategory,
        savedAt: Date = Date()
    ) {
        let coordinate = place.coordinate
        self.placeKey = Self.key(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        self.name = place.name
        self.address = place.mapItem.alongAddressText
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.categoryRawValue = category.rawValue
        self.savedAt = savedAt
    }

    var category: FlexibleStopCategory {
        FlexibleStopCategory(rawValue: categoryRawValue) ?? .custom
    }

    var snapshot: SavedPlaceSnapshot {
        SavedPlaceSnapshot(
            placeKey: placeKey,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            category: category
        )
    }

    static func key(for place: PlannedPlace) -> String {
        key(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        )
    }

    static func key(latitude: Double, longitude: Double) -> String {
        String(format: "%.5f,%.5f", latitude, longitude)
    }
}

struct SavedPlaceSnapshot: Sendable {
    let placeKey: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let category: FlexibleStopCategory

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var plannedPlace: PlannedPlace {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let item: MKMapItem

        if #available(iOS 26.0, *) {
            item = MKMapItem(location: location, address: nil)
        } else {
            item = MKMapItem(
                placemark: MKPlacemark(
                    coordinate: CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            )
        }

        item.name = name
        return PlannedPlace(mapItem: item)
    }
}
