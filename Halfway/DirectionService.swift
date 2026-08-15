import Foundation
import MapKit
import Combine


// MARK: - One Route Leg

struct RouteLeg: Identifiable {

    let id = UUID()

    let from: PlannedPlace
    let to: PlannedPlace

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

    @Published private(set)
    var routeLegs: [RouteLeg] = []

    @Published private(set)
    var isLoading = false

    @Published private(set)
    var errorMessage: String?


    private var activeDirections:
        MKDirections?


    // MARK: - Totals

    var totalDistance: CLLocationDistance {

        routeLegs.reduce(0) {
            $0 + $1.distance
        }
    }


    var totalTravelTime: TimeInterval {

        routeLegs.reduce(0) {
            $0 + $1.travelTime
        }
    }


    // MARK: - Build Route

    func buildRoute(
        for places: [PlannedPlace],
        travelMode: TravelMode
    ) {

        cancel()

        errorMessage = nil
        routeLegs = []


        guard places.count >= 2 else {

            isLoading = false
            return
        }


        isLoading = true


        calculateLeg(
            index: 0,
            places: places,
            travelMode: travelMode,
            accumulatedLegs: []
        )
    }


    // MARK: - Calculate Individual Leg

    private func calculateLeg(
        index: Int,
        places: [PlannedPlace],
        travelMode: TravelMode,
        accumulatedLegs: [RouteLeg]
    ) {

        // Finished all legs

        guard index < places.count - 1 else {

            DispatchQueue.main.async {

                self.routeLegs =
                    accumulatedLegs

                self.isLoading = false

                self.activeDirections = nil
            }

            return
        }


        let source =
            places[index]

        let destination =
            places[index + 1]


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
                request: request
            )


        activeDirections =
            directions


        directions.calculate {
            [weak self]
            response,
            error in

            guard let self else {
                return
            }


            DispatchQueue.main.async {

                if let error {

                    self.errorMessage =
                        error.localizedDescription

                    self.isLoading = false

                    self.activeDirections = nil

                    return
                }


                guard
                    let route =
                        response?
                            .routes
                            .first

                else {

                    self.errorMessage =
                        "No route could be found between \(source.name) and \(destination.name)."

                    self.isLoading = false

                    self.activeDirections = nil

                    return
                }


                let leg =
                    RouteLeg(
                        from: source,
                        to: destination,
                        route: route
                    )


                var updatedLegs =
                    accumulatedLegs

                updatedLegs.append(
                    leg
                )


                self.calculateLeg(
                    index: index + 1,
                    places: places,
                    travelMode: travelMode,
                    accumulatedLegs: updatedLegs
                )
            }
        }
    }


    // MARK: - Cancel

    func cancel() {

        activeDirections?
            .cancel()

        activeDirections = nil

        isLoading = false
    }


    // MARK: - Clear

    func clear() {

        cancel()

        routeLegs = []

        errorMessage = nil
    }
}
