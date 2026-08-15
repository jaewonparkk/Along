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
            return "e.g. Japanese, Korean, cheap"

        case .dinner:
            return "e.g. Italian, cozy"

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


    /*
     These ranges are NOT used by the
     optimizer yet.

     They give us a clean semantic model
     for the next planning-engine step.
     */

    var preferredHourRange: ClosedRange<Int>? {

        switch self {

        case .anytime:
            return nil

        case .morning:
            return 7...11

        case .midday:
            return 11...14

        case .afternoon:
            return 14...17

        case .evening:
            return 17...20

        case .night:
            return 20...23

        case .specific:
            return nil
        }
    }
}


// MARK: - Stay Duration

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


    var title: String {

        switch self {

        case .unspecified:
            return "No preference"

        case .quick:
            return "Quick stop"

        case .thirtyMinutes:
            return "30 min"

        case .oneHour:
            return "1 hr"

        case .ninetyMinutes:
            return "1.5 hr"

        case .twoHours:
            return "2 hr"

        case .custom:
            return "Custom"
        }
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

    var category: FlexibleStopCategory

    /*
     Natural-language detail.

     Examples:
     matcha
     Japanese
     pretty and quiet
     wine bar
     vintage clothes
     */

    var query: String


    var isRequired: Bool


    // MARK: Time

    var timePreference:
        FlexibleStopTimePreference


    /*
     Only meaningful when
     timePreference == .specific
     */

    var specificTime: Date


    // MARK: Stay Duration

    var stayDuration:
        StopDurationPreference


    var customStayMinutes: Int


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


    var preferredStayMinutes: Int? {

        stayDuration.minutes(
            customMinutes:
                customStayMinutes
        )
    }
}


// MARK: - Start Preference

enum StartPreference:
    String,
    CaseIterable,
    Identifiable,
    Hashable {

    case noPreference
    case eatFirst
    case coffeeFirst
    case anchorsFirst


    var id: String {
        rawValue
    }


    var title: String {

        switch self {

        case .noPreference:
            return "No preference"

        case .eatFirst:
            return "Eat first"

        case .coffeeFirst:
            return "Coffee first"

        case .anchorsFirst:
            return "Must-visits first"
        }
    }


    var subtitle: String {

        switch self {

        case .noPreference:
            return "Let Halfway decide what makes the most sense"

        case .eatFirst:
            return "Prioritize a meal near the beginning"

        case .coffeeFirst:
            return "Prioritize coffee near the beginning"

        case .anchorsFirst:
            return "Visit fixed places before flexible stops"
        }
    }
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
            return "Balance place quality and travel time"

        case .lessTravel:
            return "Favor the smallest detours"

        case .bestMatch:
            return "Prioritize places that best match what you typed"

        case .morePlaces:
            return "Favor an efficient schedule with more stops"
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
            return "Make the most of the available time"
        }
    }


    /*
     Used in the NEXT optimizer step.

     Generic planning behavior only;
     nothing location-specific.
     */

    var defaultBufferMinutes: Int {

        switch self {

        case .relaxed:
            return 30

        case .balanced:
            return 15

        case .packed:
            return 5
        }
    }
}


// MARK: - Plan Intent

struct PlanIntent {

    // MARK: Day Window

    var dayStart: Date

    var finishBy: Date


    // MARK: Style

    var pace: DayPace

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


    /*
     If someone chooses:

     Start 5 PM
     Finish 1 AM

     treat 1 AM as the following day.
     */

    var normalizedFinishBy: Date {

        if finishBy > dayStart {

            return finishBy
        }


        return Calendar.current
            .date(
                byAdding: .day,
                value: 1,
                to: finishBy
            )
            ??
            finishBy
    }


    var availableDuration:
        TimeInterval {

        normalizedFinishBy
            .timeIntervalSince(
                dayStart
            )
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

    var id: UUID {
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


// MARK: - Generated Itinerary

struct GeneratedItinerary {

    let orderedPlaces:
        [PlannedPlace]

    let resolvedFlexibleStops:
        [ResolvedFlexibleStop]
}
