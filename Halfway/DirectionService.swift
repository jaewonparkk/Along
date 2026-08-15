import Foundation
import MapKit
import CoreLocation
import Combine


// MARK: - Route Leg

struct RouteLeg: Identifiable {

    let id = UUID()


    let fromPlaceID: UUID?

    let toPlaceID: UUID?


    let fromName: String

    let toName: String


    let route: MKRoute


    var distance: CLLocationDistance {

        route.distance
    }


    var travelTime: TimeInterval {

        route.expectedTravelTime
    }
}


// MARK: - Directions Service

final class DirectionsService: ObservableObject {

    // MARK: - Published

    @Published private(set)
    var routeLegs: [RouteLeg] = []


    @Published private(set)
    var isLoading: Bool = false


    @Published private(set)
    var errorMessage: String?


    // MARK: - Async State

    private var activeDirections:
        [MKDirections] = []


    private var generation:
        Int = 0


    // MARK: - Internal Endpoint

    private struct RouteEndpoint {

        let mapItem: MKMapItem

        let placeID: UUID?

        let name: String
    }


    // MARK: - Totals

    var totalTravelTime: TimeInterval {

        routeLegs.reduce(0) {

            $0 + $1.travelTime
        }
    }


    var totalDistance: CLLocationDistance {

        routeLegs.reduce(0) {

            $0 + $1.distance
        }
    }


    // MARK: - Build Route

    func buildRoute(
        for places: [PlannedPlace],
        from userLocation: CLLocation?,
        travelMode: TravelMode,
        completion: @escaping (Bool) -> Void
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


            completion(
                true
            )

            return
        }


        var endpoints:
            [RouteEndpoint] = []


        // MARK: Current Location

        if let userLocation {

            endpoints.append(
                RouteEndpoint(
                    mapItem:
                        makeMapItem(
                            for:
                                userLocation
                        ),

                    placeID:
                        nil,

                    name:
                        "Current Location"
                )
            )
        }


        // MARK: Planned Places

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


        /*
         If there is no current location
         and only one place, there is
         nothing to route between.
         */

        guard endpoints.count >= 2 else {

            isLoading =
                false


            completion(
                true
            )

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


    // MARK: - Build Sequential Legs

    private func buildLeg(
        endpoints: [RouteEndpoint],
        index: Int,
        travelMode: TravelMode,
        generation: Int,
        builtLegs: [RouteLeg],
        completion: @escaping (Bool) -> Void
    ) {

        guard generation == self.generation else {
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


            completion(
                true
            )

            return
        }


        let source =
            endpoints[index]


        let destination =
            endpoints[index + 1]


        // MARK: Avoid Same Point Requests

        let sourceCoordinate =
            source
                .mapItem
                .halfwayCoordinate


        let destinationCoordinate =
            destination
                .mapItem
                .halfwayCoordinate


        let sourceLocation =
            CLLocation(
                latitude:
                    sourceCoordinate.latitude,

                longitude:
                    sourceCoordinate.longitude
            )


        let destinationLocation =
            CLLocation(
                latitude:
                    destinationCoordinate.latitude,

                longitude:
                    destinationCoordinate.longitude
            )


        /*
         If two MapKit items are essentially
         the same coordinate, just skip
         the meaningless route leg.
         */

        if sourceLocation.distance(
            from:
                destinationLocation
        ) < 10 {

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


        // MARK: Real MKDirections Request

        let request =
            MKDirections.Request()


        request.source =
            source.mapItem


        request.destination =
            destination.mapItem


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
            [weak self]
            response,
            error in


            guard let self else {
                return
            }


            DispatchQueue.main.async {

                guard generation ==
                        self.generation
                else {

                    return
                }


                // MARK: Error

                if let error {

                    print(
                        """
                        🗺 Final route failed
                        From: \(source.name)
                        To: \(destination.name)
                        Mode: \(travelMode.title)
                        Error: \(error)
                        """
                    )


                    self.errorMessage =
                        "I built the itinerary, but couldn't get a \(travelMode.title.lowercased()) route from \(source.name) to \(destination.name)."


                    self.routeLegs =
                        builtLegs


                    self.isLoading =
                        false


                    completion(
                        false
                    )

                    return
                }


                // MARK: Route

                guard let route =
                        response?
                            .routes
                            .first
                else {

                    self.errorMessage =
                        "No \(travelMode.title.lowercased()) route was available from \(source.name) to \(destination.name)."


                    self.routeLegs =
                        builtLegs


                    self.isLoading =
                        false


                    completion(
                        false
                    )

                    return
                }


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


                var updatedLegs =
                    builtLegs


                updatedLegs.append(
                    leg
                )


                // MARK: Next Leg

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
                        updatedLegs,

                    completion:
                        completion
                )
            }
        }
    }


    // MARK: - Current Location Map Item

    private func makeMapItem(
        for location: CLLocation
    ) -> MKMapItem {

        if #available(iOS 26.0, *) {

            let item =
                MKMapItem(
                    location:
                        location,

                    address:
                        nil
                )


            item.name =
                "Current Location"


            return item

        } else {

            let placemark =
                MKPlacemark(
                    coordinate:
                        location.coordinate
                )


            let item =
                MKMapItem(
                    placemark:
                        placemark
                )


            item.name =
                "Current Location"


            return item
        }
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
