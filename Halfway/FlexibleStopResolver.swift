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
                "Halfway couldn't find a real place matching “\(query)”."
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
            CLLocationDistance
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


            for query in queries {

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

                        let key =
                            candidateKey(
                                candidate
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
                            candidate
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

        case .breakfast:

            queries.append(
                "\(detail) breakfast"
            )


            queries.append(
                "\(detail) restaurant"
            )


        case .lunch:

            queries.append(
                "\(detail) lunch"
            )


            queries.append(
                "\(detail) restaurant"
            )


        case .dinner:

            queries.append(
                "\(detail) dinner"
            )


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

        case .breakfast:

            return "breakfast"


        case .lunch:

            return "lunch restaurant"


        case .dinner:

            return "dinner restaurant"


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
