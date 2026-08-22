import Foundation
import CoreLocation
import GooglePlaces


// MARK: - Resolver Error

enum FlexibleStopResolverError:
    LocalizedError {

    case noResults(
        String
    )


    var errorDescription: String? {

        switch self {

        case .noResults(
            let query
        ):

            return
                "Along couldn't find a real place matching “\(query)”."
        }
    }
}


// MARK: - Flexible Stop Resolver

@MainActor
final class FlexibleStopResolver {

    private let placesService =
        GooglePlacesService.shared


    // MARK: - Search

    func searchCandidates(
        for stop:
            FlexibleStop,

        center:
            CLLocationCoordinate2D,

        radiusMeters:
            CLLocationDistance,

        savedPlaces:
            [SavedPlaceSnapshot] = []
    ) async throws -> [PlaceCandidate] {

        let queries =
            makeQueries(
                for:
                    stop
            )


        var seen:
            Set<String> = []


        var merged:
            [PlaceCandidate] = []


        // MARK: Saved Along Places First

        let centerLocation = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )

        let savedRadius = min(10_000, max(2_500, radiusMeters * 1.5))

        let nearbySavedPlaces = savedPlaces
            .filter { saved in
                (saved.category == stop.category || stop.category == .custom)
                && saved.location.distance(from: centerLocation) <= savedRadius
            }
            .sorted {
                $0.location.distance(from: centerLocation)
                < $1.location.distance(from: centerLocation)
            }

        for (index, saved) in nearbySavedPlaces.prefix(8).enumerated() {
            try Task.checkCancellation()

            let enriched = await placesService.enrich(
                anchor: saved.plannedPlace
            )

            let candidate = PlaceCandidate(
                plannedPlace: enriched.plannedPlace,
                googlePlace: enriched.googlePlace,
                searchRank: index,
                isSavedByUser: true,
                queryPriority: 0
            )

            let key = candidateKey(candidate)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(candidate)
        }


        /*
         Start locally.

         If necessary, progressively expand.

         Generic radius expansion only:
         no city is encoded anywhere.
         */

        let radiusScales:
            [Double] = [
                1,
                2,
                4
            ]


        for scale
            in radiusScales {

            let radius =
                min(
                    50_000,

                    max(
                        1_000,
                        radiusMeters
                        *
                        scale
                    )
                )


            for (queryPriority, query) in queries.enumerated() {

                if Task.isCancelled {

                    return []
                }


                do {

                    let candidates =
                        try await placesService.search(
                            text:
                                query,

                            center:
                                center,

                            radiusMeters:
                                radius
                        )


                    for candidate
                        in candidates {

                        let rankedCandidate = PlaceCandidate(
                            plannedPlace: candidate.plannedPlace,
                            googlePlace: candidate.googlePlace,
                            searchRank: candidate.searchRank,
                            queryPriority: queryPriority
                        )

                        let key =
                            candidateKey(
                                rankedCandidate
                            )


                        guard !seen.contains(
                            key
                        ) else {

                            continue
                        }


                        seen.insert(
                            key
                        )


                        merged.append(
                            rankedCandidate
                        )
                    }


                    /*
                     Healthy candidate pool.
                     No need to keep expanding.
                     */

                    if merged.count >= 15 {

                        return Array(
                            merged.prefix(
                                20
                            )
                        )
                    }

                } catch {

                    print(
                        """
                        🔎 Google place query skipped
                        \(query)
                        \(error.localizedDescription)
                        """
                    )
                }
            }
        }


        guard !merged.isEmpty else {

            let label =
                stop.query
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )


            throw FlexibleStopResolverError
                .noResults(
                    label.isEmpty
                    ?
                    stop.category.title
                    :
                    label
                )
        }


        return Array(
            merged.prefix(
                20
            )
        )
    }


    // MARK: - Queries

    private func makeQueries(
        for stop:
            FlexibleStop
    ) -> [String] {

        let detail =
            stop.query
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        /*
         Don't throw away what the user typed.

         "sandwiches" should NOT silently
         degrade into "any lunch restaurant".
         */

        guard !detail.isEmpty else {

            return [
                genericCategoryQuery(
                    for:
                        stop.category
                )
            ]
        }


        var queries:
            [String] = [
                detail
            ]


        switch stop.category {

        case .food:
            queries.append(
                "\(detail) restaurant"
            )


        case .coffee:

            queries.append(
                "\(detail) cafe"
            )


            queries.append(
                "\(detail) coffee"
            )


        case .dessert:

            queries.append(
                "\(detail) dessert"
            )


        case .drinks:

            queries.append(
                "\(detail) bar"
            )


        case .shopping:

            queries.append(
                "\(detail) shop"
            )


        case .activity:

            queries.append(
                "\(detail) attraction"
            )


        case .outdoors:

            queries.append(
                "\(detail) outdoor"
            )


        case .custom:

            break
        }


        // Final fallback: if the user's exact phrase has no useful result,
        // still return a sensible nearby place in the requested category.
        queries.append(
            genericCategoryQuery(for: stop.category)
        )


        return uniqueStrings(
            queries
        )
    }


    // MARK: - Empty Query Category

    private func genericCategoryQuery(
        for category:
            FlexibleStopCategory
    ) -> String {

        switch category {

        case .food:

            return "restaurant"


        case .coffee:

            return "cafe"


        case .dessert:

            return "dessert"


        case .drinks:

            return "bar"


        case .shopping:

            return "shopping"


        case .activity:

            return "things to do"


        case .outdoors:

            return "outdoor attraction"


        case .custom:

            return "places"
        }
    }


    // MARK: - Candidate Key

    private func candidateKey(
        _ candidate:
            PlaceCandidate
    ) -> String {

        if let googleID =
            candidate
                .googlePlace?
                .placeID {

            return googleID
        }


        let coordinate =
            candidate
                .plannedPlace
                .coordinate


        return String(
            format:
                "%.5f,%.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }


    // MARK: - Unique Strings

    private func uniqueStrings(
        _ values:
            [String]
    ) -> [String] {

        var seen:
            Set<String> = []


        var result:
            [String] = []


        for value in values {

            let cleaned =
                value
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )


            let key =
                cleaned.lowercased()


            guard
                !cleaned.isEmpty,
                !seen.contains(
                    key
                )
            else {

                continue
            }


            seen.insert(
                key
            )


            result.append(
                cleaned
            )
        }


        return result
    }


    func cancel() {

        /*
         Search calls are owned by the current
         Swift Task. PlanningEngine cancels
         that task when a new plan begins.
         */
    }
}
