import Foundation
import CoreLocation
import MapKit
import Combine


@MainActor
final class PlanningEngine:
    ObservableObject {

    // MARK: - Published

    @Published private(set)
    var isPlanning:
        Bool = false


    @Published private(set)
    var progressMessage:
        String = ""


    @Published private(set)
    var generatedItinerary:
        GeneratedItinerary?


    @Published private(set)
    var errorMessage:
        String?


    // MARK: - Services

    private let placesService =
        GooglePlacesService.shared


    private let resolver =
        FlexibleStopResolver()


    private let constraintEngine =
        ScheduleConstraintEngine()


    // MARK: - Task State

    private var currentTask:
        Task<Void, Never>?


    private var generation:
        Int = 0


    // MARK: - Build

    func build(
        plan:
            PlanRequest,

        userLocation:
            CLLocation?,

        travelMode:
            TravelMode,

        completion:
            @escaping (
                GeneratedItinerary?
            ) -> Void
    ) {

        cancel()


        generation += 1


        let runID =
            generation


        isPlanning =
            true


        progressMessage =
            "Preparing your day..."


        errorMessage =
            nil


        generatedItinerary =
            nil


        currentTask =
            Task {
                [weak self] in


                guard let self else {
                    return
                }


                do {

                    // MARK: Empty Plan

                    guard
                        !plan.anchors.isEmpty
                        ||
                        !plan.flexibleStops.isEmpty
                    else {

                        let empty =
                            GeneratedItinerary(
                                orderedPlaces:
                                    [],

                                resolvedFlexibleStops:
                                    [],

                                skippedFlexibleStops:
                                    [],

                                scheduledStops:
                                    []
                            )


                        guard
                            runID
                            ==
                            self.generation
                        else {

                            return
                        }


                        self.generatedItinerary =
                            empty


                        self.isPlanning =
                            false


                        self.progressMessage =
                            ""


                        completion(
                            empty
                        )


                        return
                    }


                    // MARK: Geographic Context

                    guard let context =
                            self.makeSearchContext(
                                plan:
                                    plan,

                                userLocation:
                                    userLocation
                            )
                    else {

                        throw PlanningEngineError
                            .missingLocation
                    }


                    // MARK: Enrich Must-Visits

                    self.progressMessage =
                        "Checking must-visit opening hours..."


                    var anchorCandidates:
                        [PlaceCandidate] = []


                    for (
                        index,
                        anchor
                    ) in plan
                        .anchors
                        .enumerated() {

                        try Task
                            .checkCancellation()


                        self.progressMessage =
                            "Checking \(anchor.place.name) hours (\(index + 1)/\(plan.anchors.count))..."


                        let enriched =
                            await self
                                .placesService
                                .enrich(
                                    anchor:
                                        anchor.place
                                )


                        anchorCandidates.append(
                            enriched
                        )
                    }


                    // MARK: Resolve Flexible Search Pools

                    var flexiblePools:
                        [FlexibleCandidatePool] = []


                    for (
                        index,
                        stop
                    ) in plan
                        .flexibleStops
                        .enumerated() {

                        try Task
                            .checkCancellation()


                        let detail =
                            stop.query
                                .trimmingCharacters(
                                    in:
                                        .whitespacesAndNewlines
                                )


                        let title =
                            detail.isEmpty
                            ?
                            stop.category.title
                            :
                            detail


                        self.progressMessage =
                            "Finding \(title) options (\(index + 1)/\(plan.flexibleStops.count))..."


                        let candidates =
                            try await self
                                .resolver
                                .searchCandidates(
                                    for:
                                        stop,

                                    center:
                                        context.center,

                                    radiusMeters:
                                        context.radiusMeters
                                )


                        flexiblePools.append(
                            FlexibleCandidatePool(
                                stop:
                                    stop,

                                candidates:
                                    candidates
                            )
                        )
                    }


                    try Task
                        .checkCancellation()


                    // MARK: Constraint-Aware Day Planning

                    self.progressMessage =
                        "Checking hours, timing, and travel..."


                    let result =
                        try await self
                            .constraintEngine
                            .build(
                                anchors:
                                    anchorCandidates,

                                anchorStayMinutes:
                                    Dictionary(
                                        uniqueKeysWithValues:
                                            plan.anchors.map {
                                                ($0.place.id, $0.stayDuration.minutes(customMinutes: 120) ?? 120)
                                            }
                                    ),

                                flexiblePools:
                                    flexiblePools,

                                visitOrder:
                                    plan.visitOrder,

                                intent:
                                    plan.intent,

                                userLocation:
                                    userLocation,

                                travelMode:
                                    travelMode
                            )


                    try Task
                        .checkCancellation()


                    guard
                        runID
                        ==
                        self.generation
                    else {

                        return
                    }


                    // MARK: Final Result

                    let itinerary =
                        GeneratedItinerary(
                            orderedPlaces:
                                result
                                    .orderedPlaces,

                            resolvedFlexibleStops:
                                result
                                    .resolvedFlexibleStops,

                            skippedFlexibleStops:
                                [],

                            scheduledStops:
                                result
                                    .scheduledStops
                        )


                    self.generatedItinerary =
                        itinerary


                    self.isPlanning =
                        false


                    self.progressMessage =
                        ""


                    completion(
                        itinerary
                    )

                } catch is CancellationError {

                    /*
                     A new planning run replaced
                     this one. No alert needed.
                     */


                } catch {

                    guard
                        runID
                        ==
                        self.generation
                    else {

                        return
                    }


                    self.isPlanning =
                        false


                    self.progressMessage =
                        ""


                    self.errorMessage =
                        error.localizedDescription


                    completion(
                        nil
                    )
                }
            }
    }


    // MARK: - Search Context

    private struct SearchContext {

        let center:
            CLLocationCoordinate2D


        let radiusMeters:
            CLLocationDistance
    }


    private func makeSearchContext(
        plan:
            PlanRequest,

        userLocation:
            CLLocation?
    ) -> SearchContext? {

        var coordinates =
            plan
                .anchorPlaces
                .map {

                    $0.coordinate
                }


        if let userLocation {

            coordinates.append(
                userLocation.coordinate
            )
        }


        guard !coordinates.isEmpty else {

            return nil
        }


        // MARK: Center

        let averageLatitude =
            coordinates.reduce(
                0
            ) {

                $0 + $1.latitude

            }
            /
            Double(
                coordinates.count
            )


        let averageLongitude =
            coordinates.reduce(
                0
            ) {

                $0 + $1.longitude

            }
            /
            Double(
                coordinates.count
            )


        let center =
            CLLocationCoordinate2D(
                latitude:
                    averageLatitude,

                longitude:
                    averageLongitude
            )


        // MARK: Dynamic Radius

        let centerLocation =
            CLLocation(
                latitude:
                    center.latitude,

                longitude:
                    center.longitude
            )


        let largestDistance =
            coordinates
                .map {
                    coordinate in


                    CLLocation(
                        latitude:
                            coordinate.latitude,

                        longitude:
                            coordinate.longitude
                    )
                    .distance(
                        from:
                            centerLocation
                    )
                }
                .max()
            ??
            0


        /*
         Generic planning margin.

         No Boston / city / POI
         information is hardcoded.
         */

        let radius =
            min(
                50_000,

                max(
                    4_000,

                    largestDistance
                    *
                    1.5
                    +
                    2_500
                )
            )


        return SearchContext(
            center:
                center,

            radiusMeters:
                radius
        )
    }


    // MARK: - Error

    func dismissError() {

        errorMessage =
            nil
    }


    // MARK: - Clear

    func clearGeneratedPlan() {

        generatedItinerary =
            nil
    }


    // MARK: - Cancel

    func cancel() {

        generation += 1


        currentTask?
            .cancel()


        currentTask =
            nil


        resolver.cancel()


        constraintEngine.cancel()


        isPlanning =
            false


        progressMessage =
            ""
    }
}


// MARK: - Planning Error

enum PlanningEngineError:
    LocalizedError {

    case missingLocation


    var errorDescription:
        String? {

        switch self {

        case .missingLocation:

            return
                """
                Along needs either your location or at least one must-visit place to know where to search.
                """
        }
    }
}
