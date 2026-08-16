import Foundation
import MapKit
import CoreLocation


// MARK: - MKMapItem Helpers

extension MKMapItem {

    var alongCoordinate: CLLocationCoordinate2D {

        if #available(iOS 26.0, *) {
            return location.coordinate
        } else {
            return placemark.coordinate
        }
    }


    var alongAddressText: String {

        if #available(iOS 26.0, *) {

            if let fullAddress = address?.fullAddress,
               !fullAddress.isEmpty {

                return fullAddress
            }

            if let shortAddress = address?.shortAddress,
               !shortAddress.isEmpty {

                return shortAddress
            }

            return ""

        } else {

            return placemark.title ?? ""
        }
    }
}


// MARK: - Planned Place

struct PlannedPlace: Identifiable {

    let id = UUID()

    let mapItem: MKMapItem


    var name: String {

        mapItem.name
        ?? "Unnamed Place"
    }


    var coordinate: CLLocationCoordinate2D {

        mapItem.alongCoordinate
    }
}
