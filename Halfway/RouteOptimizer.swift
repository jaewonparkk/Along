import Foundation
import MapKit
import CoreLocation


// MARK: - Route Optimizer Error

enum RouteOptimizerError: LocalizedError {

    case unableToBuildRoute


    var errorDescription: String? {

        switch self {

        case .unableToBuildRoute:

            return "I couldn't find a complete route between these places."
        }
    }
}


// MARK: - Route Optimizer

final class RouteOptimizer {

    // MARK: - Edge

    private struct EdgeKey: Hashable {

        /*
         -1 = user's current location

         0...n = selected places
         */

        let from: Int
        let to: Int
    }


    // MARK: - State

    private var activeDirections:
        [MKDirections] = []


    private var activeRunID:
        UUID?


    // MARK: - Optimize

    func optimize(
        places: [PlannedPlace],
        userLocation: CLLocation?,
        travelMode: TravelMode,
        completion:
            @escaping (
                Result<
                    [PlannedPlace],
                    Error
                >
            ) -> Void
    ) {

        cancel()


        let runID =
            UUID()


        activeRunID =
            runID


        guard places.count > 1 else {

            completion(
                .success(
                    places
                )
            )

            return
        }


        let tasks =
            makeMatrixTasks(
                numberOfPlaces:
                    places.count,

                includeCurrentLocation:
                    userLocation != nil
            )


        calculateMatrixTask(
            tasks:
                tasks,

            taskIndex:
                0,

            places:
                places,

            userLocation:
                userLocation,

            travelMode:
                travelMode,

            runID:
                runID,

            matrix:
                [:]

        ) {
            [weak self]
            matrix in


            guard let self else {
                return
            }


            guard self.activeRunID == runID else {
                return
            }


            guard
                let optimizedIndices =
                    self.findBestOrder(
                        numberOfPlaces:
                            places.count,

                        matrix:
                            matrix,

                        includeCurrentLocation:
                            userLocation != nil
                    )

            else {

                completion(
                    .failure(
                        RouteOptimizerError
                            .unableToBuildRoute
                    )
                )

                return
            }


            let result =
                optimizedIndices.map {

                    places[$0]
                }


            completion(
                .success(
                    result
                )
            )
        }
    }


    // MARK: - Matrix Tasks

    private func makeMatrixTasks(
        numberOfPlaces: Int,
        includeCurrentLocation: Bool
    ) -> [EdgeKey] {

        var tasks:
            [EdgeKey] = []


        // Current location → every place

        if includeCurrentLocation {

            for destination
                in 0..<numberOfPlaces {

                tasks.append(
                    EdgeKey(
                        from: -1,
                        to: destination
                    )
                )
            }
        }


        // Every place → every other place

        for source
            in 0..<numberOfPlaces {

            for destination
                in 0..<numberOfPlaces {

                guard source != destination else {
                    continue
                }


                tasks.append(
                    EdgeKey(
                        from: source,
                        to: destination
                    )
                )
            }
        }


        return tasks
    }


    // MARK: - Calculate Matrix

    private func calculateMatrixTask(
        tasks: [EdgeKey],
        taskIndex: Int,
        places: [PlannedPlace],
        userLocation: CLLocation?,
        travelMode: TravelMode,
        runID: UUID,
        matrix: [EdgeKey: TimeInterval],
        completion:
            @escaping (
                [EdgeKey: TimeInterval]
            ) -> Void
    ) {

        guard activeRunID == runID else {
            return
        }


        // Finished

        guard taskIndex < tasks.count else {

            completion(
                matrix
            )

            return
        }


        let edge =
            tasks[taskIndex]


        // MARK: Source

        let source:
            MKMapItem


        if edge.from == -1 {

            guard let userLocation else {

                calculateMatrixTask(
                    tasks:
                        tasks,

                    taskIndex:
                        taskIndex + 1,

                    places:
                        places,

                    userLocation:
                        userLocation,

                    travelMode:
                        travelMode,

                    runID:
                        runID,

                    matrix:
                        matrix,

                    completion:
                        completion
                )


                return
            }


            source =
                makeMapItem(
                    for:
                        userLocation
                )

        } else {

            source =
                places[
                    edge.from
                ]
                .mapItem
        }


        // MARK: Destination

        let destination =
            places[
                edge.to
            ]
            .mapItem


        calculateTravelTime(
            from:
                source,

            to:
                destination,

            travelMode:
                travelMode,

            runID:
                runID

        ) {
            [weak self]
            time in


            guard let self else {
                return
            }


            guard self.activeRunID == runID else {
                return
            }


            var updatedMatrix =
                matrix


            /*
             HUGE FIX:

             One route failure does NOT
             terminate the whole optimizer.

             We simply don't add this edge.
             */

            if let time {

                updatedMatrix[edge] =
                    time
            }


            self.calculateMatrixTask(
                tasks:
                    tasks,

                taskIndex:
                    taskIndex + 1,

                places:
                    places,

                userLocation:
                    userLocation,

                travelMode:
                    travelMode,

                runID:
                    runID,

                matrix:
                    updatedMatrix,

                completion:
                    completion
            )
        }
    }


    // MARK: - ETA

    private func calculateTravelTime(
        from source: MKMapItem,
        to destination: MKMapItem,
        travelMode: TravelMode,
        runID: UUID,
        completion:
            @escaping (
                TimeInterval?
            ) -> Void
    ) {

        let sourceCoordinate =
            source.halfwayCoordinate


        let destinationCoordinate =
            destination.halfwayCoordinate


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
         Same/essentially identical point.

         Avoid asking MapKit for a pointless
         route.
         */

        if sourceLocation.distance(
            from:
                destinationLocation
        ) < 10 {

            completion(
                0
            )

            return
        }


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


        directions.calculateETA {
            [weak self]
            response,
            error in


            guard let self else {
                return
            }


            guard self.activeRunID == runID else {
                return
            }


            if let error {

                /*
                 Don't crash the plan.

                 This edge is simply unavailable.
                 */

                print(
                    """
                    🧭 ETA skipped
                    From: \(source.name ?? "Unknown")
                    To: \(destination.name ?? "Unknown")
                    Mode: \(travelMode.title)
                    Error: \(error)
                    """
                )


                completion(
                    nil
                )

                return
            }


            guard let response else {

                completion(
                    nil
                )

                return
            }


            completion(
                response.expectedTravelTime
            )
        }
    }


    // MARK: - Concrete Current Location Map Item

    private func makeMapItem(
        for location: CLLocation
    ) -> MKMapItem {

        /*
         Don't use MKMapItem.forCurrentLocation()
         inside optimizer calculations.

         We already HAVE the real CLLocation.

         Use that concrete coordinate.
         */

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


    // MARK: - Best Order

    private func findBestOrder(
        numberOfPlaces: Int,
        matrix: [EdgeKey: TimeInterval],
        includeCurrentLocation: Bool
    ) -> [Int]? {

        var bestRoute:
            [Int]?


        var bestScore =
            TimeInterval
                .greatestFiniteMagnitude


        /*
         Try every place as possible
         starting point.
         */

        for startingIndex
            in 0..<numberOfPlaces {

            guard
                let route =
                    nearestNeighborRoute(
                        startIndex:
                            startingIndex,

                        numberOfPlaces:
                            numberOfPlaces,

                        matrix:
                            matrix
                    )

            else {

                continue
            }


            let improved =
                improveWithTwoOpt(
                    route:
                        route,

                    matrix:
                        matrix,

                    includeCurrentLocation:
                        includeCurrentLocation
                )


            guard
                let cost =
                    routeCost(
                        improved,

                        matrix:
                            matrix,

                        includeCurrentLocation:
                            includeCurrentLocation
                    )

            else {

                continue
            }


            if cost < bestScore {

                bestScore =
                    cost


                bestRoute =
                    improved
            }
        }


        return bestRoute
    }


    // MARK: - Nearest Neighbor

    private func nearestNeighborRoute(
        startIndex: Int,
        numberOfPlaces: Int,
        matrix: [EdgeKey: TimeInterval]
    ) -> [Int]? {

        var route =
            [
                startIndex
            ]


        var remaining =
            Set(
                0..<numberOfPlaces
            )


        remaining.remove(
            startIndex
        )


        var current =
            startIndex


        while !remaining.isEmpty {

            var bestNext:
                Int?


            var bestTime =
                TimeInterval
                    .greatestFiniteMagnitude


            for candidate in remaining {

                let edge =
                    EdgeKey(
                        from:
                            current,

                        to:
                            candidate
                    )


                guard
                    let time =
                        matrix[edge]

                else {

                    continue
                }


                if time < bestTime {

                    bestTime =
                        time


                    bestNext =
                        candidate
                }
            }


            guard let next = bestNext else {

                return nil
            }


            route.append(
                next
            )


            remaining.remove(
                next
            )


            current =
                next
        }


        return route
    }


    // MARK: - 2-Opt

    private func improveWithTwoOpt(
        route: [Int],
        matrix: [EdgeKey: TimeInterval],
        includeCurrentLocation: Bool
    ) -> [Int] {

        guard route.count >= 3 else {

            return route
        }


        var bestRoute =
            route


        guard var bestScore =
                routeCost(
                    bestRoute,

                    matrix:
                        matrix,

                    includeCurrentLocation:
                        includeCurrentLocation
                )

        else {

            return route
        }


        var improved =
            true


        var pass =
            0


        while improved
            &&
            pass < 20 {

            improved =
                false


            pass +=
                1


            for start
                in 0..<(bestRoute.count - 1) {

                for end
                    in (start + 1)..<bestRoute.count {

                    var candidate =
                        bestRoute


                    candidate.replaceSubrange(
                        start...end,

                        with:
                            candidate[
                                start...end
                            ]
                            .reversed()
                    )


                    guard
                        let score =
                            routeCost(
                                candidate,

                                matrix:
                                    matrix,

                                includeCurrentLocation:
                                    includeCurrentLocation
                            )

                    else {

                        continue
                    }


                    if score < bestScore {

                        bestScore =
                            score


                        bestRoute =
                            candidate


                        improved =
                            true
                    }
                }
            }
        }


        return bestRoute
    }


    // MARK: - Route Cost

    private func routeCost(
        _ route: [Int],
        matrix: [EdgeKey: TimeInterval],
        includeCurrentLocation: Bool
    ) -> TimeInterval? {

        guard let first = route.first else {

            return 0
        }


        var total:
            TimeInterval = 0


        // Current → first stop

        if includeCurrentLocation {

            guard
                let time =
                    matrix[
                        EdgeKey(
                            from: -1,
                            to: first
                        )
                    ]

            else {

                return nil
            }


            total +=
                time
        }


        // Stop → stop

        if route.count >= 2 {

            for index
                in 0..<(route.count - 1) {

                let edge =
                    EdgeKey(
                        from:
                            route[index],

                        to:
                            route[
                                index + 1
                            ]
                    )


                guard let time = matrix[edge] else {

                    return nil
                }


                total +=
                    time
            }
        }


        return total
    }


    // MARK: - Cancel

    func cancel() {

        activeRunID =
            nil


        for directions
            in activeDirections {

            directions.cancel()
        }


        activeDirections =
            []
    }
}
