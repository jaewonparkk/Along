import Foundation
import MapKit

enum TravelMode: String, CaseIterable, Identifiable {

    case walking
    case driving
    case transit

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .walking:
            return "Walk"

        case .driving:
            return "Drive"

        case .transit:
            return "Transit"
        }
    }

    var icon: String {
        switch self {
        case .walking:
            return "figure.walk"

        case .driving:
            return "car.fill"

        case .transit:
            return "tram.fill"
        }
    }

    var mapKitType: MKDirectionsTransportType {
        switch self {
        case .walking:
            return .walking

        case .driving:
            return .automobile

        case .transit:
            return .transit
        }
    }
}
