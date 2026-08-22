import Foundation
import CoreLocation
import MapKit


enum ScheduleConstraintError:
    LocalizedError {

    case requiredPlaceUnavailable(
        String
    )

    case flexibleStopUnavailable(
        String
    )


    var errorDescription:
        String? {

        switch self {

        case .requiredPlaceUnavailable(
            let place
        ):

            return
                "\(place) isn't confirmed open long enough at this point in your visit order. Move it earlier or change your day hours."


        case .flexibleStopUnavailable(
            let stop
        ):

            return
                "Along couldn't verify an open, reachable option for \(stop) at this point in your visit order."
        }
    }
}


@MainActor
final class ScheduleConstraintEngine {

    private let placesService =
        GooglePlacesService.shared


    private var activeDirections:
        [MKDirections] = []


    private var routeCache:
        [String: TimeInterval] = [:]


    private var latestOpenCache:
        [String: Date] = [:]


    // MARK: - Internal Models

    private enum Source {

        case anchor(
            UUID
        )

        case flexible(
            UUID,
            FlexibleStop
        )
    }


    private struct EffectiveTiming {

        let window:
            ClosedRange<Date>

        let label:
            String

        let isExplicit:
            Bool
    }


    private struct EvaluatedOption {

        let source:
            Source

        let candidate:
            PlaceCandidate

        let travelTime:
            TimeInterval

        let arrival:
            Date

        let start:
            Date

        let departure:
            Date

        let timingStatus:
            ScheduleTimingStatus

        let requestedTiming:
            String?

        let warning:
            String?

        let score:
            Double
    }


    // MARK: - Build

    func build(
        anchors:
            [PlaceCandidate],

        anchorStayMinutes:
            [UUID: Int],

        flexiblePools:
            [FlexibleCandidatePool],

        visitOrder:
            [PlanRequest.StopReference],

        intent:
            PlanIntent,

        userLocation:
            CLLocation?,

        travelMode:
            TravelMode
    ) async throws
    -> ConstraintPlanResult {

        routeCache =
            [:]


        latestOpenCache =
            [:]


        var remainingAnchors =
            anchors


        var remainingFlexible =
            flexiblePools


        var orderedPlaces:
            [PlannedPlace] = []


        var resolvedStops:
            [ResolvedFlexibleStop] = []


        var scheduledStops:
            [ScheduledStop] = []


        var currentTime =
            intent.dayStart


        var currentMapItem:
            MKMapItem?


        if let userLocation {

            currentMapItem =
                makeLocationMapItem(
                    for:
                        userLocation
                )
        }


        while
            !remainingAnchors.isEmpty
            ||
            !remainingFlexible.isEmpty {

            try Task
                .checkCancellation()


            let isFirst =
                orderedPlaces.isEmpty


            var options:
                [EvaluatedOption] = []

            let nextReference = visitOrder.first { reference in
                switch reference {
                case .anchor(let id):
                    return remainingAnchors.contains { $0.plannedPlace.id == id }
                case .flexible(let id):
                    return remainingFlexible.contains { $0.stop.id == id }
                }
            }


            // MARK: Must Visits

            for anchor
                in remainingAnchors {

                if let nextReference, nextReference != .anchor(anchor.plannedPlace.id) { continue }

                if let evaluated =
                    await evaluate(
                        candidate:
                            anchor,

                        source:
                            .anchor(
                                anchor
                                    .plannedPlace
                                    .id
                            ),

                        flexibleStop:
                            nil,

                        stayMinutesOverride:
                            anchorStayMinutes[anchor.plannedPlace.id],

                        currentMapItem:
                            currentMapItem,

                        currentTime:
                            currentTime,

                        intent:
                            intent,

                        travelMode:
                            travelMode,

                        isFirst:
                            isFirst
                    ) {

                    options.append(
                        evaluated
                    )
                }
            }


            // MARK: Must-visits-first is REAL

            let blockFlexibleStops:
                Bool


            switch intent
                .startPreference {

            case .mustVisitsFirst:

                blockFlexibleStops =
                    !remainingAnchors
                        .isEmpty


            default:

                blockFlexibleStops =
                    false
            }


            // MARK: Flexible Stops

            if !blockFlexibleStops {

                for pool
                    in remainingFlexible {

                    if let nextReference, nextReference != .flexible(pool.stop.id) { continue }

                    for candidate
                        in pool
                            .candidates
                            .prefix(
                                8
                            ) {

                        if let evaluated =
                            await evaluate(
                                candidate:
                                    candidate,

                                source:
                                    .flexible(
                                        pool.stop.id,
                                        pool.stop
                                    ),

                                flexibleStop:
                                    pool.stop,

                                stayMinutesOverride:
                                    nil,

                                currentMapItem:
                                    currentMapItem,

                                currentTime:
                                    currentTime,

                                intent:
                                    intent,

                                travelMode:
                                    travelMode,

                                isFirst:
                                    isFirst
                            ) {

                            options.append(
                                evaluated
                            )
                        }
                    }
                }
            }


            // MARK: Nothing Feasible

            guard let best =
                    options.min(
                        by: {

                            $0.score
                            <
                            $1.score
                        }
                    )
            else {

                if let anchor =
                    remainingAnchors
                        .first {

                    throw ScheduleConstraintError
                        .requiredPlaceUnavailable(
                            anchor.name
                        )
                }


                if let stop =
                    remainingFlexible
                        .first?
                        .stop {

                    throw ScheduleConstraintError
                        .flexibleStopUnavailable(
                            stop.query.isEmpty
                            ?
                            stop.category.title
                            :
                            "\(stop.category.title) • \(stop.query)"
                        )
                }


                break
            }


            // MARK: Append

            let place =
                best
                    .candidate
                    .plannedPlace


            orderedPlaces.append(
                place
            )


            scheduledStops.append(
                ScheduledStop(
                    place:
                        place,

                    arrivalTime:
                        best.arrival,

                    startTime:
                        best.start,

                    departureTime:
                        best.departure,

                    timingStatus:
                        best.timingStatus,

                    requestedTiming:
                        best.requestedTiming,

                    warning:
                        best.warning
                )
            )


            switch best.source {

            case .anchor(
                let id
            ):

                remainingAnchors
                    .removeAll {

                        $0
                            .plannedPlace
                            .id
                        ==
                        id
                    }


            case .flexible(
                let id,
                let stop
            ):

                remainingFlexible
                    .removeAll {

                        $0.stop.id
                        ==
                        id
                    }


                resolvedStops.append(
                    ResolvedFlexibleStop(
                        source:
                            stop,

                        place:
                            place,

                        insertionIndex:
                            orderedPlaces.count - 1,

                        addedTravelTime:
                            best.travelTime
                    )
                )
            }


            let finished =
                remainingAnchors.isEmpty
                &&
                remainingFlexible.isEmpty


            let buffer =
                finished
                ?
                0
                :
                intent
                    .pace
                    .defaultBufferMinutes


            currentTime =
                best
                    .departure
                    .addingTimeInterval(
                        TimeInterval(
                            buffer * 60
                        )
                    )


            currentMapItem =
                place.mapItem
        }


        return ConstraintPlanResult(
            orderedPlaces:
                orderedPlaces,

            resolvedFlexibleStops:
                resolvedStops,

            scheduledStops:
                scheduledStops
        )
    }


    // MARK: - Evaluate

    private func evaluate(
        candidate:
            PlaceCandidate,

        source:
            Source,

        flexibleStop:
            FlexibleStop?,

        stayMinutesOverride:
            Int?,

        currentMapItem:
            MKMapItem?,

        currentTime:
            Date,

        intent:
            PlanIntent,

        travelMode:
            TravelMode,

        isFirst:
            Bool
    ) async -> EvaluatedOption? {

        // MARK: Travel

        let travel:
            TimeInterval


        if let currentMapItem {

            guard let result =
                    await travelTime(
                        from:
                            currentMapItem,

                        to:
                            candidate
                                .plannedPlace
                                .mapItem,

                        travelMode:
                            travelMode
                    )
            else {

                return nil
            }


            travel =
                result

        } else {

            travel =
                0
        }


        let arrival =
            currentTime
                .addingTimeInterval(
                    travel
                )


        // MARK: Timing

        var start =
            arrival


        var timingStatus:
            ScheduleTimingStatus =
                .noPreference


        var timingText:
            String?


        var timingPenalty:
            TimeInterval = 0


        if let flexibleStop,
           let timing =
            effectiveTiming(
                for:
                    flexibleStop,

                intent:
                    intent
            ) {

            timingText =
                timing.label


            if arrival <
                timing.window.lowerBound {

                start =
                    timing
                        .window
                        .lowerBound


                timingStatus =
                    .waitedForPreference


                let waiting =
                    start
                        .timeIntervalSince(
                            arrival
                        )


                /*
                 This is why:

                 11 AM
                 Wine = evening

                 does NOT win first.
                 */

                timingPenalty =
                    waiting
                    *
                    (
                        timing.isExplicit
                        ?
                        1.8
                        :
                        1.25
                    )


            } else if arrival <=
                        timing
                            .window
                            .upperBound {

                timingStatus =
                    .fitsPreference


            } else {

                timingStatus =
                    .outsidePreference


                let lateBy =
                    arrival
                        .timeIntervalSince(
                            timing
                                .window
                                .upperBound
                        )


                timingPenalty =
                    lateBy
                    *
                    (
                        timing.isExplicit
                        ?
                        4.0
                        :
                        2.5
                    )
            }
        }


        // MARK: Stay Duration

        let stayMinutes =
            stayMinutesOverride
            ??
            defaultStayMinutes(
                for: flexibleStop,
                pace: intent.pace
            )


        let departure =
            start
                .addingTimeInterval(
                    TimeInterval(
                        stayMinutes
                        *
                        60
                    )
                )


        var warnings: [String] = []

        if departure > intent.normalizedFinishBy {
            warnings.append("This stop finishes after your preferred end time.")
        }


        // MARK: Opening Hours Advisory

        let availability =
            await placesService
                .availability(
                    for:
                        candidate,

                    from:
                        start,

                    until:
                        departure
                )


        let hoursPenalty:
            TimeInterval


        switch availability {

        case .closed:
            // Required anchors remain visible so the user can fix the plan,
            // but a flexible recommendation known to be closed is never used.
            if flexibleStop != nil {
                return nil
            }
            hoursPenalty = 24 * 60 * 60
            warnings.append("Opening hours conflict with this visit time. Check before you go.")


        case .open:

            hoursPenalty =
                0


        case .unknown:
            // No published hours means no restriction. Preserve the user's
            // chosen order instead of rejecting the whole itinerary.
            hoursPenalty = 0
            if flexibleStop != nil {
                warnings.append("Opening hours aren't available. Check before you go.")
            }
        }


        // MARK: Anchor Closing Urgency

        var closingUrgencyBonus:
            TimeInterval = 0


        if flexibleStop == nil {

            if let latestStart =
                await latestFeasibleStart(
                    for:
                        candidate,

                    dayStart:
                        intent.dayStart,

                    dayEnd:
                        intent.normalizedFinishBy,

                    stayMinutes:
                        stayMinutes
                ) {

                /*
                 Example:

                 museum latest feasible start = 3 PM
                 day ends = 9 PM

                 urgency = 6 hours.

                 A mall open until 9 PM has
                 almost no urgency.

                 Therefore museum naturally
                 gets scheduled earlier.
                 */

                let urgency =
                    max(
                        0,

                        intent
                            .normalizedFinishBy
                            .timeIntervalSince(
                                latestStart
                            )
                    )


                closingUrgencyBonus =
                    -urgency
                    *
                    0.9
            }
        }


        // MARK: Start Preference

        var startPreferenceAdjustment:
            TimeInterval = 0


        if isFirst {

            switch intent
                .startPreference {

            case .noPreference,
                 .mustVisitsFirst:

                break


            case .flexibleStop(
                let preferredID
            ):

                switch source {

                case .flexible(
                    let actualID,
                    _
                ):

                    if actualID ==
                        preferredID {

                        startPreferenceAdjustment =
                            -8 * 60 * 60

                    } else {

                        startPreferenceAdjustment =
                            8 * 60 * 60
                    }


                case .anchor:

                    startPreferenceAdjustment =
                        8 * 60 * 60
                }
            }
        }


        // MARK: Search Relevance

        let searchRankPenalty:
            TimeInterval


        if flexibleStop != nil {

            searchRankPenalty =
                Double(
                    candidate.searchRank
                )
                *
                90

        } else {

            searchRankPenalty =
                0
        }


        // MARK: Recommendation Quality

        let recommendationBonus: TimeInterval

        if flexibleStop != nil {
            let savedPoints = candidate.isSavedByUser ? 40.0 : 0.0
            let rating = Double(candidate.googlePlace?.rating ?? 0)
            let ratingPoints = rating > 0
                ? max(0, min(25, (rating - 3.5) / 1.5 * 25))
                : 0
            let reviewCount = Double(candidate.googlePlace?.userRatingsTotal ?? 0)
            let reviewPoints = min(15, log10(max(1, reviewCount)) / 3 * 15)
            let queryPoints = max(0, 25 - Double(candidate.queryPriority) * 8)

            // One point equals three minutes of preference. Travel time is
            // still scored separately, so a far-away favorite cannot win only
            // because it was saved or highly rated.
            recommendationBonus =
                (savedPoints + ratingPoints + reviewPoints + queryPoints)
                * 3 * 60
        } else {
            recommendationBonus = 0
        }


        // MARK: Goal Weights

        let travelWeight:
            Double


        let relevanceWeight:
            Double


        switch intent
            .optimizationGoal {

        case .balanced:

            travelWeight =
                1.0

            relevanceWeight =
                1.0


        case .lessTravel:

            travelWeight =
                1.5

            relevanceWeight =
                0.6


        case .bestMatch:

            travelWeight =
                0.7

            relevanceWeight =
                1.8


        case .morePlaces:

            travelWeight =
                1.15

            relevanceWeight =
                0.8
        }


        let waiting =
            max(
                0,

                start
                    .timeIntervalSince(
                        arrival
                    )
            )


        let score =
            travel
            *
            travelWeight
            +
            waiting
            *
            1.1
            +
            timingPenalty
            +
            hoursPenalty
            +
            searchRankPenalty
            *
            relevanceWeight
            +
            closingUrgencyBonus
            +
            startPreferenceAdjustment
            -
            recommendationBonus


        return EvaluatedOption(
            source:
                source,

            candidate:
                candidate,

            travelTime:
                travel,

            arrival:
                arrival,

            start:
                start,

            departure:
                departure,

            timingStatus:
                timingStatus,

            requestedTiming:
                timingText,

            warning:
                warnings.isEmpty
                ? nil
                : warnings.joined(separator: " "),

            score:
                score
        )
    }


    // MARK: - Natural + Explicit Timing

    private func effectiveTiming(
        for stop:
            FlexibleStop,

        intent:
            PlanIntent
    ) -> EffectiveTiming? {

        // MARK: User Explicitly Chose Timing

        if stop.timePreference !=
            .anytime {

            guard let window =
                    explicitTimeWindow(
                        for:
                            stop,

                        intent:
                            intent
                    )
            else {

                return nil
            }


            return EffectiveTiming(
                window:
                    window,

                label:
                    explicitTimingLabel(
                        stop
                    ),

                isExplicit:
                    true
            )
        }


        return nil
    }


    // MARK: - Explicit Window

    private func explicitTimeWindow(
        for stop:
            FlexibleStop,

        intent:
            PlanIntent
    ) -> ClosedRange<Date>? {

        switch stop
            .timePreference {

        case .anytime:

            return nil


        case .morning:

            return makeWindow(
                startMinutes:
                    7 * 60,

                endMinutes:
                    11 * 60,

                intent:
                    intent
            )


        case .midday:

            return makeWindow(
                startMinutes:
                    11 * 60,

                endMinutes:
                    14 * 60,

                intent:
                    intent
            )


        case .afternoon:

            return makeWindow(
                startMinutes:
                    14 * 60,

                endMinutes:
                    17 * 60,

                intent:
                    intent
            )


        case .evening:

            return makeWindow(
                startMinutes:
                    17 * 60,

                endMinutes:
                    20 * 60,

                intent:
                    intent
            )


        case .night:

            return makeWindow(
                startMinutes:
                    20 * 60,

                endMinutes:
                    24 * 60,

                intent:
                    intent
            )


        case .specific:

            let target =
                normalizeSpecificTime(
                    stop.specificTime,

                    intent:
                        intent
                )


            return target
                .addingTimeInterval(
                    -30 * 60
                )
                ...
                target
                    .addingTimeInterval(
                        30 * 60
                    )
        }
    }


    // MARK: - Closing Urgency

    private func latestFeasibleStart(
        for candidate:
            PlaceCandidate,

        dayStart:
            Date,

        dayEnd:
            Date,

        stayMinutes:
            Int
    ) async -> Date? {

        let key =
            latestOpenKey(
                candidate:
                    candidate,

                dayEnd:
                    dayEnd,

                stayMinutes:
                    stayMinutes
            )


        if let cached =
            latestOpenCache[key] {

            return cached
        }


        let stay =
            TimeInterval(
                stayMinutes
                *
                60
            )


        var probe =
            dayEnd
                .addingTimeInterval(
                    -stay
                )


        /*
         Scan backwards.

         60-minute resolution is enough
         for route ordering urgency.
         */

        while probe >=
            dayStart {

            let end =
                probe
                    .addingTimeInterval(
                        stay
                    )


            let availability =
                await placesService
                    .availability(
                        for:
                            candidate,

                        from:
                            probe,

                        until:
                            end
                    )


            switch availability {

            case .open:

                latestOpenCache[key] =
                    probe


                return probe


            case .closed:

                probe =
                    probe
                        .addingTimeInterval(
                            -60 * 60
                        )


            case .unknown:

                /*
                 Can't derive trustworthy
                 closing urgency.
                 */

                return nil
            }
        }


        return nil
    }


    private func latestOpenKey(
        candidate:
            PlaceCandidate,

        dayEnd:
            Date,

        stayMinutes:
            Int
    ) -> String {

        let coordinate =
            candidate
                .plannedPlace
                .coordinate


        return String(
            format:
                "%.5f,%.5f|%.0f|%d",

            coordinate.latitude,
            coordinate.longitude,

            dayEnd.timeIntervalSince1970,

            stayMinutes
        )
    }


    // MARK: - Stay Duration

    private func defaultStayMinutes(
        for stop:
            FlexibleStop?,

        pace:
            DayPace
    ) -> Int {

        var base:
            Int


        if let explicit =
            stop?
                .preferredStayMinutes {

            return explicit
        }


        switch stop?
            .category {

        case .food:

            base = 75


        case .coffee:

            base = 45


        case .dessert:

            base = 45


        case .drinks:

            base = 90


        case .shopping:

            base = 75


        case .activity:

            base = 90


        case .outdoors:

            base = 75


        case .custom,
             .none:

            base = 60
        }


        switch pace {

        case .relaxed:

            base += 15


        case .balanced:

            break


        case .packed:

            base -= 15
        }


        return max(
            30,
            base
        )
    }


    // MARK: - Timing Label

    private func explicitTimingLabel(
        _ stop:
            FlexibleStop
    ) -> String {

        if stop.timePreference ==
            .specific {

            return stop
                .specificTime
                .formatted(
                    date:
                        .omitted,

                    time:
                        .shortened
                )
        }


        return stop
            .timePreference
            .title
    }


    // MARK: - Window Helpers

    private func makeWindow(
        startMinutes:
            Int,

        endMinutes:
            Int,

        intent:
            PlanIntent
    ) -> ClosedRange<Date> {

        let calendar =
            Calendar.current


        let day =
            calendar.startOfDay(
                for:
                    intent.dayStart
            )


        let lower =
            calendar.date(
                byAdding:
                    .minute,

                value:
                    startMinutes,

                to:
                    day
            )
            ??
            intent.dayStart


        let upper =
            calendar.date(
                byAdding:
                    .minute,

                value:
                    endMinutes,

                to:
                    day
            )
            ??
            intent.normalizedFinishBy


        return lower...upper
    }


    private func normalizeSpecificTime(
        _ selected:
            Date,

        intent:
            PlanIntent
    ) -> Date {

        let calendar =
            Calendar.current


        let hour =
            calendar.component(
                .hour,

                from:
                    selected
            )


        let minute =
            calendar.component(
                .minute,

                from:
                    selected
            )


        var date =
            calendar.date(
                bySettingHour:
                    hour,

                minute:
                    minute,

                second:
                    0,

                of:
                    intent.dayStart
            )
            ??
            selected


        if date <
            intent.dayStart,
           !calendar.isDate(
                intent.dayStart,

                inSameDayAs:
                    intent.normalizedFinishBy
           ) {

            date =
                calendar.date(
                    byAdding:
                        .day,

                    value:
                        1,

                    to:
                        date
                )
                ??
                date
        }


        return date
    }


    // MARK: - ETA

    private func travelTime(
        from source:
            MKMapItem,

        to destination:
            MKMapItem,

        travelMode:
            TravelMode
    ) async -> TimeInterval? {

        let from =
            location(
                from:
                    source
            )


        let to =
            location(
                from:
                    destination
            )


        if from.distance(
            from:
                to
        ) < 10 {

            return 0
        }


        let key =
            routeKey(
                source:
                    source,

                destination:
                    destination,

                travelMode:
                    travelMode
            )


        if let cached =
            routeCache[key] {

            return cached
        }


        if let eta =
            await requestETA(
                from:
                    source,

                to:
                    destination,

                travelMode:
                    travelMode
            ) {

            routeCache[key] =
                eta


            return eta
        }


        let retry =
            await requestETA(
                from:
                    routingMapItem(
                        from:
                            source
                    ),

                to:
                    routingMapItem(
                        from:
                            destination
                    ),

                travelMode:
                    travelMode
            )


        if let retry {

            routeCache[key] =
                retry
        }


        return retry
    }


    private func requestETA(
        from source:
            MKMapItem,

        to destination:
            MKMapItem,

        travelMode:
            TravelMode
    ) async -> TimeInterval? {

        await withCheckedContinuation {
            continuation in


            let request =
                MKDirections.Request()


            request.source =
                source


            request.destination =
                destination


            request.transportType =
                travelMode.mapKitType


            let directions =
                MKDirections(
                    request:
                        request
                )


            activeDirections.append(
                directions
            )


            directions.calculateETA {
                response,
                error in


                if let error {

                    print(
                        """
                        🧭 ETA failed
                        \(source.name ?? "?")
                        →
                        \(destination.name ?? "?")
                        \(error)
                        """
                    )
                }


                continuation.resume(
                    returning:
                        response?
                            .expectedTravelTime
                )
            }
        }
    }


    // MARK: - Map Item Helpers

    private func routingMapItem(
        from item:
            MKMapItem
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


    private func makeLocationMapItem(
        for location:
            CLLocation
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
        from item:
            MKMapItem
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


    private func routeKey(
        source:
            MKMapItem,

        destination:
            MKMapItem,

        travelMode:
            TravelMode
    ) -> String {

        let from =
            source.alongCoordinate


        let to =
            destination.alongCoordinate


        return String(
            format:
                "%.5f,%.5f→%.5f,%.5f|%@",

            from.latitude,
            from.longitude,

            to.latitude,
            to.longitude,

            travelMode.rawValue
        )
    }


    // MARK: - Cancel

    func cancel() {

        for directions
            in activeDirections {

            directions.cancel()
        }


        activeDirections =
            []


        routeCache =
            [:]


        latestOpenCache =
            [:]
    }
}
