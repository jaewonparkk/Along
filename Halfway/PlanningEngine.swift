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

    private let routeOptimizer =
        RouteOptimizer()


    // MARK: - Async State

    private var generation: Int = 0

    private var activeDirections: [MKDirections] = []

    private var routeTimeCache: [String: TimeInterval] = [:]


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
            "Preparing your day..."

        errorMessage = nil

        generatedItinerary = nil

        routeTimeCache = [:]


        let anchors =
            plan.anchorPlaces


        // MARK: Nothing Selected

        if anchors.isEmpty &&
            plan.flexibleStops.isEmpty {

            let itinerary =
                GeneratedItinerary(
                    orderedPlaces: [],
                    resolvedFlexibleStops: []
                )


            generatedItinerary =
                itinerary

            isPlanning =
                false

            progressMessage =
                ""


            completion(
                itinerary
            )

            return
        }


        // MARK: Flexible Stops Need Geographic Context

        if anchors.isEmpty &&
            !plan.flexibleStops.isEmpty &&
            userLocation == nil {

            finishWithError(
                "Add a must-visit place or allow location access so Halfway knows where to search.",
                completion: completion
            )

            return
        }


        // MARK: Optimize Anchors

        if anchors.count >= 2 {

            progressMessage =
                "Optimizing your must-visits..."


            routeOptimizer.optimize(
                places: anchors,
                userLocation: userLocation,
                travelMode: travelMode
            ) { [weak self] result in

                guard let self else {
                    return
                }


                guard currentGeneration == self.generation else {
                    return
                }


                switch result {

                case .success(let optimizedAnchors):

                    self.continueAfterAnchorOptimization(
                        optimizedAnchors: optimizedAnchors,
                        plan: plan,
                        userLocation: userLocation,
                        travelMode: travelMode,
                        generation: currentGeneration,
                        completion: completion
                    )


                case .failure(let error):

                    print(
                        """
                        🧭 Anchor optimization failed.
                        Error: \(error)
                        Falling back to user's anchor order.
                        """
                    )


                    /*
                     IMPORTANT:

                     Optimization failure should NOT
                     destroy the user's entire plan.

                     Fall back to the order they entered.
                     */

                    self.continueAfterAnchorOptimization(
                        optimizedAnchors: anchors,
                        plan: plan,
                        userLocation: userLocation,
                        travelMode: travelMode,
                        generation: currentGeneration,
                        completion: completion
                    )
                }
            }

        } else {

            /*
             0 or 1 anchor:
             nothing to reorder.
             */

            continueAfterAnchorOptimization(
                optimizedAnchors: anchors,
                plan: plan,
                userLocation: userLocation,
                travelMode: travelMode,
                generation: currentGeneration,
                completion: completion
            )
        }
    }


    // MARK: - Continue After Anchor Optimization

    private func continueAfterAnchorOptimization(
        optimizedAnchors: [PlannedPlace],
        plan: PlanRequest,
        userLocation: CLLocation?,
        travelMode: TravelMode,
        generation: Int,
        completion: @escaping (GeneratedItinerary?) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        // MARK: No Flexible Stops

        guard !plan.flexibleStops.isEmpty else {

            let itinerary =
                GeneratedItinerary(
                    orderedPlaces: optimizedAnchors,
                    resolvedFlexibleStops: []
                )


            generatedItinerary =
                itinerary

            isPlanning =
                false

            progressMessage =
                ""


            completion(
                itinerary
            )

            return
        }


        // MARK: Start Flexible Resolution

        resolveFlexibleStop(
            at: 0,
            flexibleStops: plan.flexibleStops,
            workingPlaces: optimizedAnchors,
            resolvedStops: [],
            plan: plan,
            userLocation: userLocation,
            travelMode: travelMode,
            generation: generation,
            completion: completion
        )
    }


    // MARK: - Resolve Flexible Stops

    private func resolveFlexibleStop(
        at index: Int,
        flexibleStops: [FlexibleStop],
        workingPlaces: [PlannedPlace],
        resolvedStops: [ResolvedFlexibleStop],
        plan: PlanRequest,
        userLocation: CLLocation?,
        travelMode: TravelMode,
        generation: Int,
        completion: @escaping (GeneratedItinerary?) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        // MARK: Finished All Flexible Stops

        guard index < flexibleStops.count else {

            let itinerary =
                GeneratedItinerary(
                    orderedPlaces: workingPlaces,
                    resolvedFlexibleStops: resolvedStops
                )


            generatedItinerary =
                itinerary

            isPlanning =
                false

            progressMessage =
                ""


            completion(
                itinerary
            )

            return
        }


        let stop =
            flexibleStops[index]


        progressMessage =
            "Finding \(stop.category.title.lowercased()) options..."


        let region =
            makePlanningRegion(
                places: workingPlaces,
                userLocation: userLocation
            )


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

                print(
                    """
                    🔎 Flexible stop search failed
                    Type: \(stop.category.title)
                    Query: \(stop.query)
                    Error: \(error)
                    """
                )


                if stop.isRequired {

                    self.finishWithError(
                        error.localizedDescription,
                        completion: completion
                    )

                } else {

                    self.resolveFlexibleStop(
                        at: index + 1,
                        flexibleStops: flexibleStops,
                        workingPlaces: workingPlaces,
                        resolvedStops: resolvedStops,
                        plan: plan,
                        userLocation: userLocation,
                        travelMode: travelMode,
                        generation: generation,
                        completion: completion
                    )
                }


            // MARK: Candidates Found

            case .success(let candidates):

                self.chooseBestCandidate(
                    for: stop,
                    candidates: candidates,
                    currentPlaces: workingPlaces,
                    intent: plan.intent,
                    userLocation: userLocation,
                    travelMode: travelMode,
                    generation: generation
                ) { [weak self] choice in

                    guard let self else {
                        return
                    }


                    guard generation == self.generation else {
                        return
                    }


                    // MARK: No Routable Candidate

                    guard let choice else {

                        print(
                            """
                            🧭 No routable candidate found
                            Type: \(stop.category.title)
                            Query: \(stop.query)
                            """
                        )


                        if stop.isRequired {

                            self.finishWithError(
                                "I found places for \(stop.category.title.lowercased()), but couldn't find a usable \(travelMode.title.lowercased()) route to them.",
                                completion: completion
                            )

                        } else {

                            self.resolveFlexibleStop(
                                at: index + 1,
                                flexibleStops: flexibleStops,
                                workingPlaces: workingPlaces,
                                resolvedStops: resolvedStops,
                                plan: plan,
                                userLocation: userLocation,
                                travelMode: travelMode,
                                generation: generation,
                                completion: completion
                            )
                        }


                        return
                    }


                    // MARK: Insert Selected Place

                    var updatedPlaces =
                        workingPlaces


                    let safeInsertionIndex =
                        min(
                            max(
                                choice.insertionIndex,
                                0
                            ),
                            updatedPlaces.count
                        )


                    updatedPlaces.insert(
                        choice.place,
                        at: safeInsertionIndex
                    )


                    let resolved =
                        ResolvedFlexibleStop(
                            source: stop,
                            place: choice.place,
                            insertionIndex: safeInsertionIndex,
                            addedTravelTime: choice.addedTravelTime
                        )


                    var updatedResolvedStops =
                        resolvedStops


                    updatedResolvedStops.append(
                        resolved
                    )


                    // MARK: Continue To Next Flexible Stop

                    self.resolveFlexibleStop(
                        at: index + 1,
                        flexibleStops: flexibleStops,
                        workingPlaces: updatedPlaces,
                        resolvedStops: updatedResolvedStops,
                        plan: plan,
                        userLocation: userLocation,
                        travelMode: travelMode,
                        generation: generation,
                        completion: completion
                    )
                }
            }
        }
    }


    // MARK: - Candidate Proposal

    private struct CandidateProposal {

        let place: PlannedPlace

        let appleRank: Int

        let insertionIndex: Int

        let geometricAddedDistance: CLLocationDistance
    }


    // MARK: - Scored Candidate

    private struct ScoredCandidate {

        let place: PlannedPlace

        let insertionIndex: Int

        let addedTravelTime: TimeInterval

        let score: Double
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
        completion: @escaping (ScoredCandidate?) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        progressMessage =
            "Comparing \(stop.category.title.lowercased()) options..."


        // MARK: Build Candidate Proposals

        let proposals =
            Array(
                candidates
                    .prefix(8)
            )
            .enumerated()
            .map { index, mapItem in

                let place =
                    PlannedPlace(
                        mapItem: mapItem
                    )


                let insertionIndex =
                    preferredInsertionIndex(
                        for: stop,
                        candidate: place,
                        currentPlaces: currentPlaces,
                        startPreference: intent.startPreference,
                        userLocation: userLocation
                    )


                let geometricDistance =
                    geometricAddedDistance(
                        candidate: place,
                        insertionIndex: insertionIndex,
                        currentPlaces: currentPlaces,
                        userLocation: userLocation
                    )


                return CandidateProposal(
                    place: place,
                    appleRank: index,
                    insertionIndex: insertionIndex,
                    geometricAddedDistance: geometricDistance
                )
            }


        guard !proposals.isEmpty else {

            completion(
                nil
            )

            return
        }


        // MARK: Cheap Preliminary Ranking

        let sortedProposals =
            proposals.sorted { first, second in

                preliminaryScore(
                    first,
                    goal: intent.optimizationGoal
                )
                <
                preliminaryScore(
                    second,
                    goal: intent.optimizationGoal
                )
            }


        /*
         Real MKDirections requests are more
         expensive, so only run actual ETA
         calculations on the strongest few.
         */

        let finalists =
            Array(
                sortedProposals
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
                rank * 1000


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


    // MARK: - Evaluate Finalists

    private func evaluateFinalists(
        _ finalists: [CandidateProposal],
        index: Int,
        currentPlaces: [PlannedPlace],
        userLocation: CLLocation?,
        travelMode: TravelMode,
        goal: OptimizationGoal,
        generation: Int,
        best: ScoredCandidate?,
        completion: @escaping (ScoredCandidate?) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        // MARK: Finished

        guard index < finalists.count else {

            completion(
                best
            )

            return
        }


        let proposal =
            finalists[index]


        actualAddedTravelTime(
            candidate: proposal.place,
            insertionIndex: proposal.insertionIndex,
            currentPlaces: currentPlaces,
            userLocation: userLocation,
            travelMode: travelMode
        ) { [weak self] addedTravelTime in

            guard let self else {
                return
            }


            guard generation == self.generation else {
                return
            }


            var updatedBest =
                best


            // MARK: Route Exists

            if let addedTravelTime {

                let score =
                    self.finalCandidateScore(
                        addedTravelTime: addedTravelTime,
                        appleRank: proposal.appleRank,
                        goal: goal
                    )


                let scored =
                    ScoredCandidate(
                        place: proposal.place,
                        insertionIndex: proposal.insertionIndex,
                        addedTravelTime: addedTravelTime,
                        score: score
                    )


                if updatedBest == nil {

                    updatedBest =
                        scored

                } else if score < updatedBest!.score {

                    updatedBest =
                        scored
                }
            }


            // MARK: Continue

            self.evaluateFinalists(
                finalists,
                index: index + 1,
                currentPlaces: currentPlaces,
                userLocation: userLocation,
                travelMode: travelMode,
                goal: goal,
                generation: generation,
                best: updatedBest,
                completion: completion
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

            /*
             Search relevance gets a
             considerably larger role.
             */

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

        // MARK: Empty Route

        guard !currentPlaces.isEmpty else {

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


        // MARK: Find Best Geometric Insertion

        var bestIndex =
            0


        var bestDistance =
            CLLocationDistance
                .greatestFiniteMagnitude


        for insertionIndex
            in 0...currentPlaces.count {

            let addedDistance =
                geometricAddedDistance(
                    candidate: candidate,
                    insertionIndex: insertionIndex,
                    currentPlaces: currentPlaces,
                    userLocation: userLocation
                )


            if addedDistance < bestDistance {

                bestDistance =
                    addedDistance

                bestIndex =
                    insertionIndex
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
                for: candidate
            )


        // MARK: Empty Route

        if currentPlaces.isEmpty {

            if let userLocation {

                return userLocation.distance(
                    from: candidateLocation
                )
            }


            return 0
        }


        // MARK: Insert At Beginning

        if insertionIndex == 0 {

            let nextLocation =
                location(
                    for: currentPlaces[0]
                )


            if let userLocation {

                let newDistance =
                    userLocation.distance(
                        from: candidateLocation
                    )
                    +
                    candidateLocation.distance(
                        from: nextLocation
                    )


                let oldDistance =
                    userLocation.distance(
                        from: nextLocation
                    )


                return max(
                    0,
                    newDistance - oldDistance
                )
            }


            return candidateLocation.distance(
                from: nextLocation
            )
        }


        // MARK: Insert At End

        if insertionIndex >= currentPlaces.count {

            guard let previousPlace =
                    currentPlaces.last
            else {

                return 0
            }


            let previousLocation =
                location(
                    for: previousPlace
                )


            return previousLocation.distance(
                from: candidateLocation
            )
        }


        // MARK: Insert Between Two Existing Stops

        let previousPlace =
            currentPlaces[
                insertionIndex - 1
            ]


        let nextPlace =
            currentPlaces[
                insertionIndex
            ]


        let previousLocation =
            location(
                for: previousPlace
            )


        let nextLocation =
            location(
                for: nextPlace
            )


        let newDistance =
            previousLocation.distance(
                from: candidateLocation
            )
            +
            candidateLocation.distance(
                from: nextLocation
            )


        let oldDistance =
            previousLocation.distance(
                from: nextLocation
            )


        return max(
            0,
            newDistance - oldDistance
        )
    }


    // MARK: - Weighted Route Leg

    private struct WeightedRouteLeg {

        let source: MKMapItem

        let destination: MKMapItem

        /*
         +1 = route is added
         -1 = route is removed
         */

        let multiplier: Double
    }


    // MARK: - Actual Added Travel Time

    private func actualAddedTravelTime(
        candidate: PlannedPlace,
        insertionIndex: Int,
        currentPlaces: [PlannedPlace],
        userLocation: CLLocation?,
        travelMode: TravelMode,
        completion: @escaping (TimeInterval?) -> Void
    ) {

        var legs: [WeightedRouteLeg] = []


        // MARK: Empty Route

        if currentPlaces.isEmpty {

            if let userLocation {

                let currentLocationItem =
                    makeMapItem(
                        for: userLocation
                    )


                legs.append(
                    WeightedRouteLeg(
                        source: currentLocationItem,
                        destination: candidate.mapItem,
                        multiplier: 1
                    )
                )


                calculateWeightedTime(
                    legs,
                    travelMode: travelMode,
                    completion: completion
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


            if let userLocation {

                let currentLocationItem =
                    makeMapItem(
                        for: userLocation
                    )


                // New:
                // Current → Candidate

                legs.append(
                    WeightedRouteLeg(
                        source: currentLocationItem,
                        destination: candidate.mapItem,
                        multiplier: 1
                    )
                )


                // New:
                // Candidate → Next

                legs.append(
                    WeightedRouteLeg(
                        source: candidate.mapItem,
                        destination: next.mapItem,
                        multiplier: 1
                    )
                )


                // Remove old:
                // Current → Next

                legs.append(
                    WeightedRouteLeg(
                        source: currentLocationItem,
                        destination: next.mapItem,
                        multiplier: -1
                    )
                )

            } else {

                /*
                 No known user location.

                 We can still compare:
                 Candidate → Next
                 */

                legs.append(
                    WeightedRouteLeg(
                        source: candidate.mapItem,
                        destination: next.mapItem,
                        multiplier: 1
                    )
                )
            }


            calculateWeightedTime(
                legs,
                travelMode: travelMode,
                completion: completion
            )

            return
        }


        // MARK: Insert At End

        if insertionIndex >= currentPlaces.count {

            guard let previous =
                    currentPlaces.last
            else {

                completion(
                    0
                )

                return
            }


            legs.append(
                WeightedRouteLeg(
                    source: previous.mapItem,
                    destination: candidate.mapItem,
                    multiplier: 1
                )
            )


            calculateWeightedTime(
                legs,
                travelMode: travelMode,
                completion: completion
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


        // New:
        // Previous → Candidate

        legs.append(
            WeightedRouteLeg(
                source: previous.mapItem,
                destination: candidate.mapItem,
                multiplier: 1
            )
        )


        // New:
        // Candidate → Next

        legs.append(
            WeightedRouteLeg(
                source: candidate.mapItem,
                destination: next.mapItem,
                multiplier: 1
            )
        )


        // Remove:
        // Previous → Next

        legs.append(
            WeightedRouteLeg(
                source: previous.mapItem,
                destination: next.mapItem,
                multiplier: -1
            )
        )


        calculateWeightedTime(
            legs,
            travelMode: travelMode,
            completion: completion
        )
    }


    // MARK: - Calculate Weighted Time

    private func calculateWeightedTime(
        _ legs: [WeightedRouteLeg],
        travelMode: TravelMode,
        completion: @escaping (TimeInterval?) -> Void
    ) {

        calculateWeightedTime(
            legs,
            index: 0,
            total: 0,
            travelMode: travelMode,
            completion: completion
        )
    }


    private func calculateWeightedTime(
        _ legs: [WeightedRouteLeg],
        index: Int,
        total: TimeInterval,
        travelMode: TravelMode,
        completion: @escaping (TimeInterval?) -> Void
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
            from: leg.source,
            to: leg.destination,
            travelMode: travelMode
        ) { [weak self] result in

            guard let self else {
                return
            }


            guard let travelTime = result else {

                completion(
                    nil
                )

                return
            }


            let updatedTotal =
                total
                +
                (
                    travelTime
                    *
                    leg.multiplier
                )


            self.calculateWeightedTime(
                legs,
                index: index + 1,
                total: updatedTotal,
                travelMode: travelMode,
                completion: completion
            )
        }
    }


    // MARK: - Travel Time

    private func travelTime(
        from source: MKMapItem,
        to destination: MKMapItem,
        travelMode: TravelMode,
        completion: @escaping (TimeInterval?) -> Void
    ) {

        // MARK: Avoid Pointless Same-Place Route Requests

        let sourceCoordinate =
            source.halfwayCoordinate


        let destinationCoordinate =
            destination.halfwayCoordinate


        let sourceLocation =
            CLLocation(
                latitude: sourceCoordinate.latitude,
                longitude: sourceCoordinate.longitude
            )


        let destinationLocation =
            CLLocation(
                latitude: destinationCoordinate.latitude,
                longitude: destinationCoordinate.longitude
            )


        if sourceLocation.distance(
            from: destinationLocation
        ) < 10 {

            completion(
                0
            )

            return
        }


        // MARK: Cache

        let cacheKey =
            routeCacheKey(
                from: source,
                to: destination,
                travelMode: travelMode
            )


        if let cachedTravelTime =
            routeTimeCache[cacheKey] {

            completion(
                cachedTravelTime
            )

            return
        }


        // MARK: Directions Request

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
                request: request
            )


        activeDirections.append(
            directions
        )


        /*
         We only need ETA here,
         not the full route geometry.
         */

        directions.calculateETA { [weak self] response, error in

            guard let self else {
                return
            }


            if let error {

                print(
                    """
                    🧭 Planning ETA skipped
                    From: \(source.name ?? "Unknown")
                    To: \(destination.name ?? "Unknown")
                    Mode: \(travelMode.title)
                    Error: \(error)
                    """
                )


                /*
                 One failed MapKit edge should not
                 crash the app.

                 This candidate is treated as
                 unavailable instead.
                 */

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


            let time =
                response.expectedTravelTime


            self.routeTimeCache[cacheKey] =
                time


            completion(
                time
            )
        }
    }


    // MARK: - Current Location MKMapItem

    private func makeMapItem(
        for location: CLLocation
    ) -> MKMapItem {

        /*
         IMPORTANT:

         Use the concrete CLLocation we already
         received from LocationManager.

         Do NOT use MKMapItem.forCurrentLocation()
         inside the optimizer.
         */


        if #available(iOS 26.0, *) {

            let item =
                MKMapItem(
                    location: location,
                    address: nil
                )


            item.name =
                "Current Location"


            return item

        } else {

            let placemark =
                MKPlacemark(
                    coordinate: location.coordinate
                )


            let item =
                MKMapItem(
                    placemark: placemark
                )


            item.name =
                "Current Location"


            return item
        }
    }


    // MARK: - Route Cache Key

    private func routeCacheKey(
        from source: MKMapItem,
        to destination: MKMapItem,
        travelMode: TravelMode
    ) -> String {

        let sourceKey =
            mapItemKey(
                source
            )


        let destinationKey =
            mapItemKey(
                destination
            )


        return "\(sourceKey)→\(destinationKey)|\(travelMode.rawValue)"
    }


    private func mapItemKey(
        _ item: MKMapItem
    ) -> String {

        let coordinate =
            item.halfwayCoordinate


        return String(
            format:
                "%.6f,%.6f",
            coordinate.latitude,
            coordinate.longitude
        )
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


        // MARK: One Point

        if coordinates.count == 1 {

            return MKCoordinateRegion(
                center: coordinates[0],
                span:
                    MKCoordinateSpan(
                        latitudeDelta: 0.08,
                        longitudeDelta: 0.08
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
                    )
                    /
                    2,

                longitude:
                    (
                        minimumLongitude
                        +
                        maximumLongitude
                    )
                    /
                    2
            )


        let latitudeSpread =
            maximumLatitude
            -
            minimumLatitude


        let longitudeSpread =
            maximumLongitude
            -
            minimumLongitude


        /*
         These are generic search-region
         tuning values.

         No city/location is hardcoded.
         */

        let latitudeDelta =
            max(
                0.08,
                latitudeSpread * 1.8
            )


        let longitudeDelta =
            max(
                0.08,
                longitudeSpread * 1.8
            )


        return MKCoordinateRegion(
            center: center,
            span:
                MKCoordinateSpan(
                    latitudeDelta: latitudeDelta,
                    longitudeDelta: longitudeDelta
                )
        )
    }


    // MARK: - CLLocation Helper

    private func location(
        for place: PlannedPlace
    ) -> CLLocation {

        CLLocation(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        )
    }


    // MARK: - Finish With Error

    private func finishWithError(
        _ message: String,
        completion: @escaping (GeneratedItinerary?) -> Void
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


    // MARK: - Public Controls

    func dismissError() {

        errorMessage =
            nil
    }


    func clearGeneratedPlan() {

        generatedItinerary =
            nil
    }


    // MARK: - Cancel Current Work

    private func cancelCurrentWork() {

        resolver.cancel()


        routeOptimizer.cancel()


        for directions in activeDirections {

            directions.cancel()
        }


        activeDirections =
            []
    }


    // MARK: - Cancel

    func cancel() {

        generation += 1


        cancelCurrentWork()


        isPlanning =
            false


        progressMessage =
            ""
    }
}
