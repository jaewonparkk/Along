import Foundation
import GooglePlaces


// MARK: - Hours Availability

enum PlaceHoursAvailability {

    case open
    case closed
    case unknown
}


// MARK: - Candidate

struct PlaceCandidate: Identifiable {

    var id: UUID {

        plannedPlace.id
    }


    let plannedPlace:
        PlannedPlace


    /*
     Google metadata is separate from
     our MapKit routing object.

     MapKit:
       route / ETA / map

     Google:
       opening hours / place metadata
     */

    let googlePlace:
        GMSPlace?


    /*
     Lower is better.

     This comes from the original
     natural-language search result ordering.
     */

    let searchRank:
        Int


    var name: String {

        plannedPlace.name
    }
}


// MARK: - Flexible Candidate Pool

struct FlexibleCandidatePool {

    let stop:
        FlexibleStop


    let candidates:
        [PlaceCandidate]
}


// MARK: - Constraint Planner Result

struct ConstraintPlanResult {

    let orderedPlaces:
        [PlannedPlace]


    let resolvedFlexibleStops:
        [ResolvedFlexibleStop]


    let scheduledStops:
        [ScheduledStop]
}
