import Foundation


// MARK: - Anchor Stop

struct AnchorStop: Identifiable {

    let id: UUID

    var place: PlannedPlace

    var isRequired: Bool


    init(
        id: UUID = UUID(),
        place: PlannedPlace,
        isRequired: Bool = true
    ) {

        self.id = id
        self.place = place
        self.isRequired = isRequired
    }
}


// MARK: - Flexible Stop Category

enum FlexibleStopCategory:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case breakfast
    case lunch
    case dinner
    case coffee
    case dessert
    case drinks
    case shopping
    case activity
    case outdoors
    case custom


    var id: String {
        rawValue
    }


    var title: String {

        switch self {

        case .breakfast:
            return "Breakfast"

        case .lunch:
            return "Lunch"

        case .dinner:
            return "Dinner"

        case .coffee:
            return "Coffee"

        case .dessert:
            return "Dessert"

        case .drinks:
            return "Drinks"

        case .shopping:
            return "Shopping"

        case .activity:
            return "Things to do"

        case .outdoors:
            return "Outdoors"

        case .custom:
            return "Something else"
        }
    }


    var icon: String {

        switch self {

        case .breakfast:
            return "sunrise.fill"

        case .lunch,
             .dinner:
            return "fork.knife"

        case .coffee:
            return "cup.and.saucer.fill"

        case .dessert:
            return "birthday.cake.fill"

        case .drinks:
            return "wineglass.fill"

        case .shopping:
            return "bag.fill"

        case .activity:
            return "sparkles"

        case .outdoors:
            return "leaf.fill"

        case .custom:
            return "plus.circle.fill"
        }
    }


    var placeholder: String {

        switch self {

        case .breakfast:
            return "e.g. brunch, pancakes"

        case .lunch:
            return "e.g. Italian, sandwiches, Korean"

        case .dinner:
            return "e.g. steak, sushi, cozy Italian"

        case .coffee:
            return "e.g. matcha, pretty, quiet"

        case .dessert:
            return "e.g. ice cream, pastries"

        case .drinks:
            return "e.g. wine bar, cocktails, rooftop"

        case .shopping:
            return "e.g. vintage, clothes"

        case .activity:
            return "e.g. museum, arcade"

        case .outdoors:
            return "e.g. park, waterfront"

        case .custom:
            return "What do you want to do?"
        }
    }


    var isMeal: Bool {

        switch self {

        case .breakfast,
             .lunch,
             .dinner:
            return true

        default:
            return false
        }
    }


    // MARK: Natural Timing

    /*
     This is NOT a hardcoded place rule.

     It is semantic meaning:

     Breakfast ≠ 8 PM
     Dinner ≠ 1 PM

     User-specified timing overrides this.
     */

    var naturalTimeWindowMinutes:
        ClosedRange<Int>? {

        switch self {

        case .breakfast:
            return
                (7 * 60)...(11 * 60)


        case .lunch:
            return
                (11 * 60)...(14 * 60)


        case .dinner:
            return
                (17 * 60)...(21 * 60)


        case .drinks:
            return
                (17 * 60)...(23 * 60)


        default:
            return nil
        }
    }


    var naturalTimingLabel: String? {

        switch self {

        case .breakfast:
            return "Breakfast time"

        case .lunch:
            return "Lunch time"

        case .dinner:
            return "Dinner time"

        case .drinks:
            return "Evening"

        default:
            return nil
        }
    }
}


// MARK: - Flexible Stop Time Preference

enum FlexibleStopTimePreference:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case anytime
    case morning
    case midday
    case afternoon
    case evening
    case night
    case specific


    var id: String {
        rawValue
    }


    var title: String {

        switch self {

        case .anytime:
            return "Anytime"

        case .morning:
            return "Morning"

        case .midday:
            return "Midday"

        case .afternoon:
            return "Afternoon"

        case .evening:
            return "Evening"

        case .night:
            return "Night"

        case .specific:
            return "Specific time"
        }
    }


    var icon: String {

        switch self {

        case .anytime:
            return "clock"

        case .morning:
            return "sunrise.fill"

        case .midday:
            return "sun.max.fill"

        case .afternoon:
            return "sun.haze.fill"

        case .evening:
            return "sunset.fill"

        case .night:
            return "moon.stars.fill"

        case .specific:
            return "clock.badge.checkmark"
        }
    }
}


// MARK: - Stop Duration

enum StopDurationPreference:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case unspecified
    case quick
    case thirtyMinutes
    case oneHour
    case ninetyMinutes
    case twoHours
    case custom


    var id: String {
        rawValue
    }


    func minutes(
        customMinutes: Int
    ) -> Int? {

        switch self {

        case .unspecified:
            return nil

        case .quick:
            return 15

        case .thirtyMinutes:
            return 30

        case .oneHour:
            return 60

        case .ninetyMinutes:
            return 90

        case .twoHours:
            return 120

        case .custom:
            return customMinutes
        }
    }
}


// MARK: - Flexible Stop

struct FlexibleStop: Identifiable {

    let id: UUID

    var category:
        FlexibleStopCategory

    var query:
        String

    var isRequired:
        Bool

    var timePreference:
        FlexibleStopTimePreference

    var specificTime:
        Date

    var stayDuration:
        StopDurationPreference

    var customStayMinutes:
        Int


    init(
        id: UUID = UUID(),
        category: FlexibleStopCategory,
        query: String = "",
        isRequired: Bool = true,
        timePreference:
            FlexibleStopTimePreference = .anytime,
        specificTime: Date = Date(),
        stayDuration:
            StopDurationPreference = .unspecified,
        customStayMinutes: Int = 60
    ) {

        self.id = id
        self.category = category
        self.query = query
        self.isRequired = isRequired

        self.timePreference =
            timePreference

        self.specificTime =
            specificTime

        self.stayDuration =
            stayDuration

        self.customStayMinutes =
            customStayMinutes
    }


    var preferredStayMinutes:
        Int? {

        stayDuration.minutes(
            customMinutes:
                customStayMinutes
        )
    }
}


// MARK: - Start Preference

enum StartPreference:
    Hashable {

    /*
     No more:
     coffeeFirst
     eatFirst

     because those options should only exist
     when the user actually requested them.
     */

    case noPreference

    case mustVisitsFirst

    case flexibleStop(UUID)
}


// MARK: - Optimization Goal

enum OptimizationGoal:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case balanced
    case lessTravel
    case bestMatch
    case morePlaces


    var id: String {
        rawValue
    }


    var title: String {

        switch self {

        case .balanced:
            return "Balanced"

        case .lessTravel:
            return "Less travel"

        case .bestMatch:
            return "Best matches"

        case .morePlaces:
            return "Fit more places"
        }
    }


    var subtitle: String {

        switch self {

        case .balanced:
            return "Balance timing, place quality, and travel"

        case .lessTravel:
            return "Favor smaller detours"

        case .bestMatch:
            return "Favor places that best match what you typed"

        case .morePlaces:
            return "Make efficient use of your available time"
        }
    }
}


// MARK: - Day Pace

enum DayPace:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case relaxed
    case balanced
    case packed


    var id: String {
        rawValue
    }


    var title: String {

        switch self {

        case .relaxed:
            return "Relaxed"

        case .balanced:
            return "Balanced"

        case .packed:
            return "Packed"
        }
    }


    var subtitle: String {

        switch self {

        case .relaxed:
            return "More breathing room between stops"

        case .balanced:
            return "A comfortable amount to do"

        case .packed:
            return "Fit more into the day"
        }
    }


    var defaultBufferMinutes:
        Int {

        switch self {

        case .relaxed:
            return 25

        case .balanced:
            return 15

        case .packed:
            return 5
        }
    }
}


// MARK: - Plan Intent

struct PlanIntent {

    var dayStart:
        Date

    var finishBy:
        Date

    var pace:
        DayPace

    var startPreference:
        StartPreference

    var optimizationGoal:
        OptimizationGoal


    init(
        dayStart: Date? = nil,
        finishBy: Date? = nil,
        pace: DayPace = .balanced,
        startPreference:
            StartPreference = .noPreference,
        optimizationGoal:
            OptimizationGoal = .balanced
    ) {

        let calendar =
            Calendar.current


        let now =
            Date()


        self.dayStart =
            dayStart
            ??
            calendar.date(
                bySettingHour: 11,
                minute: 0,
                second: 0,
                of: now
            )
            ??
            now


        self.finishBy =
            finishBy
            ??
            calendar.date(
                bySettingHour: 21,
                minute: 0,
                second: 0,
                of: now
            )
            ??
            now


        self.pace =
            pace

        self.startPreference =
            startPreference

        self.optimizationGoal =
            optimizationGoal
    }


    var normalizedFinishBy:
        Date {

        if finishBy > dayStart {

            return finishBy
        }


        return Calendar.current
            .date(
                byAdding:
                    .day,
                value:
                    1,
                to:
                    finishBy
            )
            ??
            finishBy
    }
}


// MARK: - Plan Request

struct PlanRequest {

    var anchors:
        [AnchorStop]

    var flexibleStops:
        [FlexibleStop]

    var intent:
        PlanIntent


    init(
        anchors:
            [AnchorStop] = [],
        flexibleStops:
            [FlexibleStop] = [],
        intent:
            PlanIntent = PlanIntent()
    ) {

        self.anchors =
            anchors

        self.flexibleStops =
            flexibleStops

        self.intent =
            intent
    }


    var anchorPlaces:
        [PlannedPlace] {

        anchors.map {
            $0.place
        }
    }
}


// MARK: - Resolved Flexible Stop

struct ResolvedFlexibleStop:
    Identifiable {

    var id:
        UUID {

        source.id
    }


    let source:
        FlexibleStop

    let place:
        PlannedPlace

    let insertionIndex:
        Int

    let addedTravelTime:
        TimeInterval
}


// MARK: - Skipped Flexible Stop

struct SkippedFlexibleStop:
    Identifiable {

    var id:
        UUID {

        source.id
    }


    let source:
        FlexibleStop

    let reason:
        String
}


// MARK: - Timing Status

enum ScheduleTimingStatus:
    String,
    Hashable {

    case noPreference
    case fitsPreference
    case waitedForPreference
    case outsidePreference
}


// MARK: - Scheduled Stop

struct ScheduledStop:
    Identifiable {

    var id:
        UUID {

        place.id
    }


    let place:
        PlannedPlace

    let arrivalTime:
        Date

    let startTime:
        Date

    let departureTime:
        Date

    let timingStatus:
        ScheduleTimingStatus

    let requestedTiming:
        String?
}


// MARK: - Generated Itinerary

struct GeneratedItinerary {

    let orderedPlaces:
        [PlannedPlace]

    let resolvedFlexibleStops:
        [ResolvedFlexibleStop]

    let skippedFlexibleStops:
        [SkippedFlexibleStop]

    let scheduledStops:
        [ScheduledStop]


    init(
        orderedPlaces:
            [PlannedPlace],

        resolvedFlexibleStops:
            [ResolvedFlexibleStop],

        skippedFlexibleStops:
            [SkippedFlexibleStop] = [],

        scheduledStops:
            [ScheduledStop] = []
    ) {

        self.orderedPlaces =
            orderedPlaces

        self.resolvedFlexibleStops =
            resolvedFlexibleStops

        self.skippedFlexibleStops =
            skippedFlexibleStops

        self.scheduledStops =
            scheduledStops
    }


    var estimatedFinishTime:
        Date? {

        scheduledStops
            .last?
            .departureTime
    }


    var hasTimingConflicts:
        Bool {

        scheduledStops.contains {

            $0.timingStatus
            ==
            .outsidePreference
        }
    }
}
