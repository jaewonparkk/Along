import Foundation
import MapKit
import CoreLocation
import Combine


// MARK: - Planning Engine

final class PlanningEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set)
    var isPlanning: Bool = false

    @Published private(set)
    var progressMessage: String = ""

    @Published private(set)
    var generatedItinerary: GeneratedItinerary?

    @Published private(set)
    var errorMessage: String?


    // MARK: - Services

    private let resolver =
        FlexibleStopResolver()


    // MARK: - Async State

    private var generation: Int = 0

    private var activeDirections:
        [MKDirections] = []

    private var routeTimeCache:
        [String: TimeInterval] = [:]


    // MARK: - Build Plan

    func build(
        plan: PlanRequest,
        userLocation: CLLocation?,
        travelMode: TravelMode,
        completion: @escaping (GeneratedItinerary?) -> Void
    ) {

        cancelCurrentWork()

        generation += 1

        let currentGeneration =
            generation


        isPlanning = true

        progressMessage =
            "Preparing your plan..."

        errorMessage = nil

        generatedItinerary = nil

        routeTimeCache = [:]


        let startingPlaces =
            plan.anchorPlaces


        // Flexible-only plans need some
        // geographical reference.

        if startingPlaces.isEmpty &&
            !plan.flexibleStops.isEmpty &&
            userLocation == nil {

            finishWithError(
                "Add a place or allow location access so Halfway knows where to search.",
                completion: completion
            )

            return
        }


        // No flexible stops yet:
        // return anchors as-is.

        if plan.flexibleStops.isEmpty {

            let result =
                GeneratedItinerary(
                    orderedPlaces:
                        startingPlaces,

                    resolvedFlexibleStops:
                        []
                )


            generatedItinerary =
                result

            isPlanning =
                false

            progressMessage =
                ""


            completion(
                result
            )

            return
        }


        // Start resolving flexible stops.

        resolveFlexibleStop(
            at: 0,
            flexibleStops: plan.flexibleStops,
            workingPlaces: startingPlaces,
            resolvedStops: [],
            plan: plan,
            userLocation: userLocation,
            travelMode: travelMode,
            generation: currentGeneration,
            completion: completion
        )
    }


    // MARK: - Resolve Flexible Stops

    private func resolveFlexibleStop(
        at index: Int,
        flexibleStops: [FlexibleStop],

        // IMPORTANT:
        // This is intentionally NOT `inout`.
        //
        // Arrays are value types.
        // Each async planning step receives
        // its own current version.
        workingPlaces: [PlannedPlace],

        resolvedStops: [ResolvedFlexibleStop],

        plan: PlanRequest,
        userLocation: CLLocation?,
        travelMode: TravelMode,
        generation: Int,

        completion:
            @escaping (GeneratedItinerary?) -> Void
    ) {

        // Ignore stale planner work.

        guard generation == self.generation else {
            return
        }


        // MARK: Finished All Flexible Stops

        guard index < flexibleStops.count else {

            let result =
                GeneratedItinerary(
                    orderedPlaces:
                        workingPlaces,

                    resolvedFlexibleStops:
                        resolvedStops
                )


            generatedItinerary =
                result

            isPlanning =
                false

            progressMessage =
                ""

            activeDirections =
                []


            completion(
                result
            )

            return
        }


        let stop =
            flexibleStops[index]


        progressMessage =
            "Finding \(stop.category.title.lowercased()) options..."


        let region =
            makePlanningRegion(
                places:
                    workingPlaces,

                userLocation:
                    userLocation
            )


        // MARK: Search Real MapKit Candidates

        resolver.searchCandidates(
            for: stop,
            region: region
        ) { [weak self] result in

            guard let self else {
                return
            }


            guard generation == self.generation else {
                return
            }


            switch result {

            // MARK: Search Failed

            case .failure(let error):

                if stop.isRequired {

                    self.finishWithError(
                        error.localizedDescription,
                        completion:
                            completion
                    )

                } else {

                    // Optional stop:
                    // skip it and continue.

                    self.resolveFlexibleStop(
                        at:
                            index + 1,

                        flexibleStops:
                            flexibleStops,

                        workingPlaces:
                            workingPlaces,

                        resolvedStops:
                            resolvedStops,

                        plan:
                            plan,

                        userLocation:
                            userLocation,

                        travelMode:
                            travelMode,

                        generation:
                            generation,

                        completion:
                            completion
                    )
                }


            // MARK: Search Succeeded

            case .success(let candidates):

                self.chooseBestCandidate(
                    for:
                        stop,

                    candidates:
                        candidates,

                    currentPlaces:
                        workingPlaces,

                    intent:
                        plan.intent,

                    userLocation:
                        userLocation,

                    travelMode:
                        travelMode,

                    generation:
                        generation

                ) { [weak self] choice in

                    guard let self else {
                        return
                    }


                    guard generation == self.generation else {
                        return
                    }


                    // MARK: No Usable Candidate

                    guard let choice else {

                        if stop.isRequired {

                            self.finishWithError(
                                "Halfway found places for \(stop.category.title), but couldn't build a usable \(travelMode.title.lowercased()) route to them.",
                                completion:
                                    completion
                            )

                        } else {

                            self.resolveFlexibleStop(
                                at:
                                    index + 1,

                                flexibleStops:
                                    flexibleStops,

                                workingPlaces:
                                    workingPlaces,

                                resolvedStops:
                                    resolvedStops,

                                plan:
                                    plan,

                                userLocation:
                                    userLocation,

                                travelMode:
                                    travelMode,

                                generation:
                                    generation,

                                completion:
                                    completion
                            )
                        }


                        return
                    }


                    // MARK: Insert Chosen Place

                    var updatedPlaces =
                        workingPlaces


                    updatedPlaces.insert(
                        choice.place,
                        at:
                            choice.insertionIndex
                    )


                    let resolved =
                        ResolvedFlexibleStop(
                            source:
                                stop,

                            place:
                                choice.place,

                            insertionIndex:
                                choice.insertionIndex,

                            addedTravelTime:
                                choice.addedTravelTime
                        )


                    var updatedResolved =
                        resolvedStops


                    updatedResolved.append(
                        resolved
                    )


                    // Continue planning with
                    // the NEW arrays.

                    self.resolveFlexibleStop(
                        at:
                            index + 1,

                        flexibleStops:
                            flexibleStops,

                        workingPlaces:
                            updatedPlaces,

                        resolvedStops:
                            updatedResolved,

                        plan:
                            plan,

                        userLocation:
                            userLocation,

                        travelMode:
                            travelMode,

                        generation:
                            generation,

                        completion:
                            completion
                    )
                }
            }
        }
    }


    // MARK: - Candidate Models

    private struct CandidateProposal {

        let place:
            PlannedPlace

        let appleRank:
            Int

        let insertionIndex:
            Int

        let geometricAddedDistance:
            CLLocationDistance
    }


    private struct ScoredCandidate {

        let place:
            PlannedPlace

        let insertionIndex:
            Int

        let addedTravelTime:
            TimeInterval

        let finalScore:
            Double
    }


    // MARK: - Choose Best Candidate

    private func chooseBestCandidate(
        for stop: FlexibleStop,
        candidates: [MKMapItem],
        currentPlaces: [PlannedPlace],
        intent: PlanIntent,
        userLocation: CLLocation?,
        travelMode: TravelMode,
        generation: Int,
        completion:
            @escaping (ScoredCandidate?) -> Void
    ) {

        progressMessage =
            "Comparing \(stop.category.title.lowercased()) options..."


        // MapKit results retain their
        // Apple search ranking.

        let proposals =
            candidates
                .prefix(8)
                .enumerated()
                .map {
                    index,
                    mapItem in


                    let place =
                        PlannedPlace(
                            mapItem:
                                mapItem
                        )


                    let insertion =
                        preferredInsertionIndex(
                            for:
                                stop,

                            candidate:
                                place,

                            currentPlaces:
                                currentPlaces,

                            startPreference:
                                intent
                                    .startPreference,

                            userLocation:
                                userLocation
                        )


                    let addedDistance =
                        geometricAddedDistance(
                            candidate:
                                place,

                            insertionIndex:
                                insertion,

                            currentPlaces:
                                currentPlaces,

                            userLocation:
                                userLocation
                        )


                    return CandidateProposal(
                        place:
                            place,

                        appleRank:
                            index,

                        insertionIndex:
                            insertion,

                        geometricAddedDistance:
                            addedDistance
                    )
                }


        // MARK: Preliminary Ranking

        let preliminary =
            proposals.sorted {
                first,
                second in


                preliminaryScore(
                    first,
                    goal:
                        intent
                            .optimizationGoal
                )
                <
                preliminaryScore(
                    second,
                    goal:
                        intent
                            .optimizationGoal
                )
            }


        // Only perform expensive real
        // directions calculations for
        // the strongest candidates.

        let finalists =
            Array(
                preliminary
                    .prefix(4)
            )


        evaluateFinalists(
            finalists,
            index: 0,
            currentPlaces: currentPlaces,
            userLocation: userLocation,
            travelMode: travelMode,
            goal: intent.optimizationGoal,
            generation: generation,
            best: nil,
            completion: completion
        )
    }


    // MARK: - Preliminary Score

    private func preliminaryScore(
        _ proposal: CandidateProposal,
        goal: OptimizationGoal
    ) -> Double {

        let rank =
            Double(
                proposal.appleRank
            )


        switch goal {

        case .lessTravel:

            return
                proposal.geometricAddedDistance
                +
                rank * 100


        case .bestMatch:

            return
                proposal.geometricAddedDistance
                +
                rank * 1_000


        case .morePlaces:

            return
                proposal.geometricAddedDistance
                +
                rank * 250


        case .balanced:

            return
                proposal.geometricAddedDistance
                +
                rank * 400
        }
    }


    // MARK: - Evaluate Real Route Times

    private func evaluateFinalists(
        _ finalists: [CandidateProposal],
        index: Int,
        currentPlaces: [PlannedPlace],
        userLocation: CLLocation?,
        travelMode: TravelMode,
        goal: OptimizationGoal,
        generation: Int,
        best: ScoredCandidate?,
        completion:
            @escaping (ScoredCandidate?) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        guard index < finalists.count else {

            completion(
                best
            )

            return
        }


        let proposal =
            finalists[index]


        actualAddedTravelTime(
            candidate:
                proposal.place,

            insertionIndex:
                proposal.insertionIndex,

            currentPlaces:
                currentPlaces,

            hasCurrentLocation:
                userLocation != nil,

            travelMode:
                travelMode

        ) { [weak self] addedTime in

            guard let self else {
                return
            }


            guard generation == self.generation else {
                return
            }


            var updatedBest =
                best


            if let addedTime {

                let score =
                    finalCandidateScore(
                        addedTravelTime:
                            addedTime,

                        appleRank:
                            proposal.appleRank,

                        goal:
                            goal
                    )


                let candidate =
                    ScoredCandidate(
                        place:
                            proposal.place,

                        insertionIndex:
                            proposal.insertionIndex,

                        addedTravelTime:
                            addedTime,

                        finalScore:
                            score
                    )


                if updatedBest == nil ||
                    score < updatedBest!.finalScore {

                    updatedBest =
                        candidate
                }
            }


            self.evaluateFinalists(
                finalists,
                index:
                    index + 1,
                currentPlaces:
                    currentPlaces,
                userLocation:
                    userLocation,
                travelMode:
                    travelMode,
                goal:
                    goal,
                generation:
                    generation,
                best:
                    updatedBest,
                completion:
                    completion
            )
        }
    }


    // MARK: - Final Candidate Score

    private func finalCandidateScore(
        addedTravelTime: TimeInterval,
        appleRank: Int,
        goal: OptimizationGoal
    ) -> Double {

        let rank =
            Double(
                appleRank
            )


        switch goal {

        case .lessTravel:

            return
                addedTravelTime
                +
                rank * 20


        case .bestMatch:

            return
                addedTravelTime * 0.55
                +
                rank * 180


        case .morePlaces:

            return
                addedTravelTime
                +
                rank * 50


        case .balanced:

            return
                addedTravelTime
                +
                rank * 90
        }
    }


    // MARK: - Preferred Insertion Index

    private func preferredInsertionIndex(
        for stop: FlexibleStop,
        candidate: PlannedPlace,
        currentPlaces: [PlannedPlace],
        startPreference: StartPreference,
        userLocation: CLLocation?
    ) -> Int {

        if currentPlaces.isEmpty {

            return 0
        }


        // MARK: Explicit Preference

        switch startPreference {

        case .eatFirst:

            if stop.category.isMeal {

                return 0
            }


        case .coffeeFirst:

            if stop.category == .coffee {

                return 0
            }


        case .anchorsFirst:

            return currentPlaces.count


        case .noPreference:

            break
        }


        // MARK: Geometric Best Insertion

        var bestIndex =
            0


        var bestDistance =
            CLLocationDistance
                .greatestFiniteMagnitude


        for index in
            0...currentPlaces.count {

            let distance =
                geometricAddedDistance(
                    candidate:
                        candidate,

                    insertionIndex:
                        index,

                    currentPlaces:
                        currentPlaces,

                    userLocation:
                        userLocation
                )


            if distance < bestDistance {

                bestDistance =
                    distance

                bestIndex =
                    index
            }
        }


        return bestIndex
    }


    // MARK: - Geometric Added Distance

    private func geometricAddedDistance(
        candidate: PlannedPlace,
        insertionIndex: Int,
        currentPlaces: [PlannedPlace],
        userLocation: CLLocation?
    ) -> CLLocationDistance {

        let candidateLocation =
            location(
                for:
                    candidate
            )


        // MARK: No Existing Places

        if currentPlaces.isEmpty {

            if let userLocation {

                return userLocation
                    .distance(
                        from:
                            candidateLocation
                    )
            }


            return 0
        }


        // MARK: Insert First

        if insertionIndex == 0 {

            let next =
                location(
                    for:
                        currentPlaces[0]
                )


            if let userLocation {

                let newDistance =
                    userLocation
                        .distance(
                            from:
                                candidateLocation
                        )
                    +
                    candidateLocation
                        .distance(
                            from:
                                next
                        )


                let oldDistance =
                    userLocation
                        .distance(
                            from:
                                next
                        )


                return max(
                    0,
                    newDistance
                    -
                    oldDistance
                )
            }


            return candidateLocation
                .distance(
                    from:
                        next
                )
        }


        // MARK: Insert Last

        if insertionIndex ==
            currentPlaces.count {

            let previous =
                location(
                    for:
                        currentPlaces[
                            currentPlaces.count - 1
                        ]
                )


            return previous
                .distance(
                    from:
                        candidateLocation
                )
        }


        // MARK: Insert Between Stops

        let previous =
            location(
                for:
                    currentPlaces[
                        insertionIndex - 1
                    ]
            )


        let next =
            location(
                for:
                    currentPlaces[
                        insertionIndex
                    ]
            )


        let newDistance =
            previous
                .distance(
                    from:
                        candidateLocation
                )
            +
            candidateLocation
                .distance(
                    from:
                        next
                )


        let oldDistance =
            previous
                .distance(
                    from:
                        next
                )


        return max(
            0,
            newDistance
            -
            oldDistance
        )
    }


    // MARK: - Actual Added Travel Time

    private struct WeightedRouteLeg {

        let from:
            MKMapItem

        let to:
            MKMapItem

        let multiplier:
            Double
    }


    private func actualAddedTravelTime(
        candidate: PlannedPlace,
        insertionIndex: Int,
        currentPlaces: [PlannedPlace],
        hasCurrentLocation: Bool,
        travelMode: TravelMode,
        completion:
            @escaping (TimeInterval?) -> Void
    ) {

        var legs:
            [WeightedRouteLeg] = []


        // MARK: Empty Route

        if currentPlaces.isEmpty {

            if hasCurrentLocation {

                legs.append(
                    WeightedRouteLeg(
                        from:
                            MKMapItem
                                .forCurrentLocation(),

                        to:
                            candidate
                                .mapItem,

                        multiplier:
                            1
                    )
                )


                calculateWeightedTime(
                    legs,
                    travelMode:
                        travelMode,
                    completion:
                        completion
                )

                return
            }


            completion(
                0
            )

            return
        }


        // MARK: Insert At Beginning

        if insertionIndex == 0 {

            let next =
                currentPlaces[0]


            if hasCurrentLocation {

                let current =
                    MKMapItem
                        .forCurrentLocation()


                // Current → Candidate

                legs.append(
                    WeightedRouteLeg(
                        from:
                            current,

                        to:
                            candidate.mapItem,

                        multiplier:
                            1
                    )
                )


                // Candidate → Next

                legs.append(
                    WeightedRouteLeg(
                        from:
                            candidate.mapItem,

                        to:
                            next.mapItem,

                        multiplier:
                            1
                    )
                )


                // Remove original:
                // Current → Next

                legs.append(
                    WeightedRouteLeg(
                        from:
                            current,

                        to:
                            next.mapItem,

                        multiplier:
                            -1
                    )
                )

            } else {

                legs.append(
                    WeightedRouteLeg(
                        from:
                            candidate.mapItem,

                        to:
                            next.mapItem,

                        multiplier:
                            1
                    )
                )
            }


            calculateWeightedTime(
                legs,
                travelMode:
                    travelMode,
                completion:
                    completion
            )

            return
        }


        // MARK: Insert At End

        if insertionIndex ==
            currentPlaces.count {

            let previous =
                currentPlaces[
                    currentPlaces.count - 1
                ]


            legs.append(
                WeightedRouteLeg(
                    from:
                        previous.mapItem,

                    to:
                        candidate.mapItem,

                    multiplier:
                        1
                )
            )


            calculateWeightedTime(
                legs,
                travelMode:
                    travelMode,
                completion:
                    completion
            )

            return
        }


        // MARK: Insert In Middle

        let previous =
            currentPlaces[
                insertionIndex - 1
            ]


        let next =
            currentPlaces[
                insertionIndex
            ]


        // Previous → Candidate

        legs.append(
            WeightedRouteLeg(
                from:
                    previous.mapItem,

                to:
                    candidate.mapItem,

                multiplier:
                    1
            )
        )


        // Candidate → Next

        legs.append(
            WeightedRouteLeg(
                from:
                    candidate.mapItem,

                to:
                    next.mapItem,

                multiplier:
                    1
            )
        )


        // Remove Previous → Next

        legs.append(
            WeightedRouteLeg(
                from:
                    previous.mapItem,

                to:
                    next.mapItem,

                multiplier:
                    -1
            )
        )


        calculateWeightedTime(
            legs,
            travelMode:
                travelMode,
            completion:
                completion
        )
    }


    // MARK: - Weighted Route Calculation

    private func calculateWeightedTime(
        _ legs: [WeightedRouteLeg],
        travelMode: TravelMode,
        completion:
            @escaping (TimeInterval?) -> Void
    ) {

        calculateWeightedTime(
            legs,
            index:
                0,
            total:
                0,
            travelMode:
                travelMode,
            completion:
                completion
        )
    }


    private func calculateWeightedTime(
        _ legs: [WeightedRouteLeg],
        index: Int,
        total: TimeInterval,
        travelMode: TravelMode,
        completion:
            @escaping (TimeInterval?) -> Void
    ) {

        guard index < legs.count else {

            completion(
                max(
                    0,
                    total
                )
            )

            return
        }


        let leg =
            legs[index]


        travelTime(
            from:
                leg.from,

            to:
                leg.to,

            travelMode:
                travelMode

        ) { [weak self] time in

            guard let self else {
                return
            }


            guard let time else {

                completion(
                    nil
                )

                return
            }


            let updatedTotal =
                total
                +
                time
                *
                leg.multiplier


            self.calculateWeightedTime(
                legs,
                index:
                    index + 1,
                total:
                    updatedTotal,
                travelMode:
                    travelMode,
                completion:
                    completion
            )
        }
    }


    // MARK: - MKDirections Travel Time

    private func travelTime(
        from source: MKMapItem,
        to destination: MKMapItem,
        travelMode: TravelMode,
        completion:
            @escaping (TimeInterval?) -> Void
    ) {

        let key =
            routeCacheKey(
                from:
                    source,

                to:
                    destination,

                travelMode:
                    travelMode
            )


        // MARK: Cache Hit

        if let cached =
            routeTimeCache[key] {

            completion(
                cached
            )

            return
        }


        // MARK: Build Real MapKit Route Request

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
            [weak self]
            response,
            error in


            DispatchQueue.main.async {

                guard let self else {
                    return
                }


                if let error {

                    print(
                        "Planning route error:",
                        error.localizedDescription
                    )


                    completion(
                        nil
                    )

                    return
                }


                guard let route =
                        response?
                            .routes
                            .first

                else {

                    completion(
                        nil
                    )

                    return
                }


                let time =
                    route
                        .expectedTravelTime


                self.routeTimeCache[key] =
                    time


                completion(
                    time
                )
            }
        }
    }


    // MARK: - Route Cache

    private func routeCacheKey(
        from source: MKMapItem,
        to destination: MKMapItem,
        travelMode: TravelMode
    ) -> String {

        "\(mapItemKey(source))→\(mapItemKey(destination))|\(travelMode.rawValue)"
    }


    private func mapItemKey(
        _ item: MKMapItem
    ) -> String {

        if item.isCurrentLocation {

            return "CURRENT_LOCATION"
        }


        let coordinate =
            item.halfwayCoordinate


        return "\(coordinate.latitude),\(coordinate.longitude)"
    }


    // MARK: - Dynamic Planning Region

    private func makePlanningRegion(
        places: [PlannedPlace],
        userLocation: CLLocation?
    ) -> MKCoordinateRegion? {

        var coordinates =
            places.map {
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


        // MARK: Single Point

        if coordinates.count == 1 {

            return MKCoordinateRegion(
                center:
                    coordinates[0],

                span:
                    MKCoordinateSpan(
                        latitudeDelta:
                            0.08,

                        longitudeDelta:
                            0.08
                    )
            )
        }


        // MARK: Multiple Points

        let latitudes =
            coordinates.map {
                $0.latitude
            }


        let longitudes =
            coordinates.map {
                $0.longitude
            }


        guard
            let minimumLatitude =
                latitudes.min(),

            let maximumLatitude =
                latitudes.max(),

            let minimumLongitude =
                longitudes.min(),

            let maximumLongitude =
                longitudes.max()

        else {

            return nil
        }


        let center =
            CLLocationCoordinate2D(
                latitude:
                    (
                        minimumLatitude
                        +
                        maximumLatitude
                    ) / 2,

                longitude:
                    (
                        minimumLongitude
                        +
                        maximumLongitude
                    ) / 2
            )


        let latitudeSpread =
            maximumLatitude
            -
            minimumLatitude


        let longitudeSpread =
            maximumLongitude
            -
            minimumLongitude


        return MKCoordinateRegion(
            center:
                center,

            span:
                MKCoordinateSpan(
                    latitudeDelta:
                        max(
                            0.08,
                            latitudeSpread
                            *
                            1.8
                        ),

                    longitudeDelta:
                        max(
                            0.08,
                            longitudeSpread
                            *
                            1.8
                        )
                )
        )
    }


    // MARK: - Location Helper

    private func location(
        for place: PlannedPlace
    ) -> CLLocation {

        CLLocation(
            latitude:
                place.coordinate.latitude,

            longitude:
                place.coordinate.longitude
        )
    }


    // MARK: - Error

    private func finishWithError(
        _ message: String,
        completion:
            @escaping (GeneratedItinerary?) -> Void
    ) {

        isPlanning =
            false

        progressMessage =
            ""

        errorMessage =
            message


        completion(
            nil
        )
    }


    // MARK: - Public State Controls

    func dismissError() {

        errorMessage =
            nil
    }


    func clearGeneratedPlan() {

        generatedItinerary =
            nil
    }


    // MARK: - Cancellation

    private func cancelCurrentWork() {

        resolver.cancel()


        for directions in
            activeDirections {

            directions.cancel()
        }


        activeDirections =
            []
    }


    func cancel() {

        generation += 1


        cancelCurrentWork()


        isPlanning =
            false

        progressMessage =
            ""
    }
}
