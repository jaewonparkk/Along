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
            return "e.g. pretty, quiet, good matcha"

        case .dessert:
            return "e.g. ice cream, pastries"

        case .drinks:
            return "e.g. cocktails, rooftop"

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


// MARK: - Flexible Stop

struct FlexibleStop: Identifiable {

    let id: UUID

    var category: FlexibleStopCategory

    var query: String

    var isRequired: Bool


    init(
        id: UUID = UUID(),
        category: FlexibleStopCategory,
        query: String = "",
        isRequired: Bool = true
    ) {

        self.id = id
        self.category = category
        self.query = query
        self.isRequired = isRequired
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
            return "Let Halfway decide"

        case .eatFirst:
            return "Put a meal near the beginning"

        case .coffeeFirst:
            return "Put coffee near the beginning"

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
            return "Best match"

        case .morePlaces:
            return "Fit more places"
        }
    }


    var subtitle: String {

        switch self {

        case .balanced:
            return "Balance travel time and place quality"

        case .lessTravel:
            return "Prioritize the smallest detours"

        case .bestMatch:
            return "Prioritize places that best match what you typed"

        case .morePlaces:
            return "Keep the route efficient enough to fit more stops"
        }
    }
}


// MARK: - Plan Intent

struct PlanIntent {

    var startPreference:
        StartPreference

    var optimizationGoal:
        OptimizationGoal


    init(
        startPreference:
            StartPreference = .noPreference,

        optimizationGoal:
            OptimizationGoal = .balanced
    ) {

        self.startPreference =
            startPreference

        self.optimizationGoal =
            optimizationGoal
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
