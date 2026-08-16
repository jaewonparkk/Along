import Foundation
import MapKit
import CoreLocation
import Combine


// MARK: - Route Leg

struct RouteLeg: Identifiable {

    let id =
        UUID()


    let fromPlaceID:
        UUID?


    let toPlaceID:
        UUID?


    let fromName:
        String


    let toName:
        String


    let route:
        MKRoute


    var distance:
        CLLocationDistance {

        route.distance
    }


    var travelTime:
        TimeInterval {

        route.expectedTravelTime
    }
}


// MARK: - Directions Service

final class DirectionsService: ObservableObject {

    // MARK: - Published

    @Published private(set)
    var routeLegs:
        [RouteLeg] = []


    @Published private(set)
    var isLoading:
        Bool = false


    @Published private(set)
    var errorMessage:
        String?


    // MARK: - State

    private var activeDirections:
        [MKDirections] = []


    private var generation:
        Int = 0


    // MARK: - Endpoint

    private struct RouteEndpoint {

        let mapItem:
            MKMapItem

        let placeID:
            UUID?

        let name:
            String
    }


    // MARK: - Totals

    var totalTravelTime:
        TimeInterval {

        routeLegs.reduce(0) {

            $0 + $1.travelTime
        }
    }


    var totalDistance:
        CLLocationDistance {

        routeLegs.reduce(0) {

            $0 + $1.distance
        }
    }


    // MARK: - Build

    func buildRoute(
        for places: [PlannedPlace],
        from userLocation: CLLocation?,
        travelMode: TravelMode,
        completion:
            @escaping (
                Bool
            ) -> Void
    ) {

        cancel()


        generation += 1


        let currentGeneration =
            generation


        routeLegs =
            []


        errorMessage =
            nil


        guard !places.isEmpty else {

            isLoading =
                false


            completion(true)

            return
        }


        var endpoints:
            [RouteEndpoint] = []


        // MARK: Current Location

        if let userLocation {

            let current =
                makeLocationMapItem(
                    for:
                        userLocation
                )


            current.name =
                "Current Location"


            endpoints.append(
                RouteEndpoint(
                    mapItem:
                        current,
                    placeID:
                        nil,
                    name:
                        "Current Location"
                )
            )
        }


        // MARK: Places

        endpoints.append(
            contentsOf:
                places.map {
                    place in


                    RouteEndpoint(
                        mapItem:
                            place.mapItem,
                        placeID:
                            place.id,
                        name:
                            place.name
                    )
                }
        )


        guard endpoints.count >= 2 else {

            isLoading =
                false


            completion(true)

            return
        }


        isLoading =
            true


        buildLeg(
            endpoints:
                endpoints,
            index:
                0,
            travelMode:
                travelMode,
            generation:
                currentGeneration,
            builtLegs:
                [],
            completion:
                completion
        )
    }


    // MARK: - Build Leg

    private func buildLeg(
        endpoints:
            [RouteEndpoint],
        index:
            Int,
        travelMode:
            TravelMode,
        generation:
            Int,
        builtLegs:
            [RouteLeg],
        completion:
            @escaping (
                Bool
            ) -> Void
    ) {

        guard generation ==
                self.generation
        else {

            return
        }


        // MARK: Finished

        guard index <
                endpoints.count - 1
        else {

            routeLegs =
                builtLegs


            isLoading =
                false


            /*
             An itinerary is valid even when
             MapKit could not draw one segment.
             */

            completion(true)

            return
        }


        let source =
            endpoints[index]


        let destination =
            endpoints[index + 1]


        // MARK: Same Place

        if location(
            from:
                source.mapItem
        )
        .distance(
            from:
                location(
                    from:
                        destination.mapItem
                )
        )
        <
        10 {

            buildLeg(
                endpoints:
                    endpoints,
                index:
                    index + 1,
                travelMode:
                    travelMode,
                generation:
                    generation,
                builtLegs:
                    builtLegs,
                completion:
                    completion
            )

            return
        }


        // MARK: POI Request

        requestRoute(
            from:
                source.mapItem,
            to:
                destination.mapItem,
            travelMode:
                travelMode
        ) {
            [weak self]
            route in


            guard let self else {
                return
            }


            guard generation ==
                    self.generation
            else {

                return
            }


            if let route {

                self.appendAndContinue(
                    route:
                        route,
                    source:
                        source,
                    destination:
                        destination,
                    endpoints:
                        endpoints,
                    index:
                        index,
                    travelMode:
                        travelMode,
                    generation:
                        generation,
                    builtLegs:
                        builtLegs,
                    completion:
                        completion
                )

                return
            }


            // MARK: Coordinate Retry

            self.requestRoute(
                from:
                    self.routingMapItem(
                        from:
                            source.mapItem
                    ),
                to:
                    self.routingMapItem(
                        from:
                            destination.mapItem
                    ),
                travelMode:
                    travelMode
            ) {
                [weak self]
                retryRoute in


                guard let self else {
                    return
                }


                if let retryRoute {

                    self.appendAndContinue(
                        route:
                            retryRoute,
                        source:
                            source,
                        destination:
                            destination,
                        endpoints:
                            endpoints,
                        index:
                            index,
                        travelMode:
                            travelMode,
                        generation:
                            generation,
                        builtLegs:
                            builtLegs,
                        completion:
                            completion
                    )

                    return
                }


                /*
                 MAJOR CHANGE:

                 Do not delete a real stop.
                 Do not display a fatal popup.
                 Do not draw a fake route.

                 Just continue.
                 */

                print(
                    """
                    ⚠️ Final polyline unavailable
                    \(source.name) → \(destination.name)
                    The itinerary keeps both places.
                    """
                )


                self.buildLeg(
                    endpoints:
                        endpoints,
                    index:
                        index + 1,
                    travelMode:
                        travelMode,
                    generation:
                        generation,
                    builtLegs:
                        builtLegs,
                    completion:
                        completion
                )
            }
        }
    }


    // MARK: - Append Route

    private func appendAndContinue(
        route:
            MKRoute,
        source:
            RouteEndpoint,
        destination:
            RouteEndpoint,
        endpoints:
            [RouteEndpoint],
        index:
            Int,
        travelMode:
            TravelMode,
        generation:
            Int,
        builtLegs:
            [RouteLeg],
        completion:
            @escaping (
                Bool
            ) -> Void
    ) {

        let leg =
            RouteLeg(
                fromPlaceID:
                    source.placeID,
                toPlaceID:
                    destination.placeID,
                fromName:
                    source.name,
                toName:
                    destination.name,
                route:
                    route
            )


        var updated =
            builtLegs


        updated.append(
            leg
        )


        buildLeg(
            endpoints:
                endpoints,
            index:
                index + 1,
            travelMode:
                travelMode,
            generation:
                generation,
            builtLegs:
                updated,
            completion:
                completion
        )
    }


    // MARK: - Request

    private func requestRoute(
        from source:
            MKMapItem,
        to destination:
            MKMapItem,
        travelMode:
            TravelMode,
        completion:
            @escaping (
                MKRoute?
            ) -> Void
    ) {

        let request =
            MKDirections.Request()


        request.source =
            source


        request.destination =
            destination


        request.transportType =
            travelMode.mapKitType


        request.requestsAlternateRoutes =
            false


        let directions =
            MKDirections(
                request:
                    request
            )


        activeDirections.append(
            directions
        )


        directions.calculate {
            response,
            error in


            DispatchQueue.main.async {

                if let error {

                    print(
                        """
                        🗺 Route unavailable
                        \(source.name ?? "Location")
                        →
                        \(destination.name ?? "Location")
                        Error: \(error)
                        """
                    )


                    completion(nil)

                    return
                }


                completion(
                    response?
                        .routes
                        .first
                )
            }
        }
    }


    // MARK: - Routing Map Item

    private func routingMapItem(
        from item: MKMapItem
    ) -> MKMapItem {

        let coordinate =
            item.alongCoordinate


        let result =
            makeLocationMapItem(
                for:
                    CLLocation(
                        latitude:
                            coordinate.latitude,
                        longitude:
                            coordinate.longitude
                    )
            )


        result.name =
            item.name


        return result
    }


    // MARK: - Location Map Item

    private func makeLocationMapItem(
        for location: CLLocation
    ) -> MKMapItem {

        if #available(
            iOS 26.0,
            *
        ) {

            return MKMapItem(
                location:
                    location,
                address:
                    nil
            )

        } else {

            return MKMapItem(
                placemark:
                    MKPlacemark(
                        coordinate:
                            location.coordinate
                    )
            )
        }
    }


    private func location(
        from item: MKMapItem
    ) -> CLLocation {

        let coordinate =
            item.alongCoordinate


        return CLLocation(
            latitude:
                coordinate.latitude,
            longitude:
                coordinate.longitude
        )
    }


    // MARK: - Error

    func dismissError() {

        errorMessage =
            nil
    }


    // MARK: - Clear

    func clear() {

        cancel()


        routeLegs =
            []


        errorMessage =
            nil


        isLoading =
            false
    }


    // MARK: - Cancel

    func cancel() {

        generation += 1


        for directions
            in activeDirections {

            directions.cancel()
        }


        activeDirections =
            []


        isLoading =
            false
    }
}
