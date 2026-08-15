import Foundation
import MapKit


// MARK: - Flexible Stop Resolver Error

enum FlexibleStopResolverError: LocalizedError {

    case noResults(String)


    var errorDescription: String? {

        switch self {

        case .noResults(let query):

            return "I couldn't find a good place for “\(query)” nearby."
        }
    }
}


// MARK: - Flexible Stop Resolver

final class FlexibleStopResolver {

    // MARK: - Active Searches

    private var activeSearches: [MKLocalSearch] = []

    private var generation: Int = 0


    // MARK: - Search Candidates

    func searchCandidates(
        for stop: FlexibleStop,
        region: MKCoordinateRegion?,
        completion:
            @escaping (
                Result<[MKMapItem], Error>
            ) -> Void
    ) {

        cancel()


        generation += 1


        let currentGeneration =
            generation


        let queries =
            makeSearchQueries(
                for: stop
            )


        guard !queries.isEmpty else {

            completion(
                .failure(
                    FlexibleStopResolverError
                        .noResults(
                            stop.category.title
                        )
                )
            )

            return
        }


        searchQueries(
            queries,
            queryIndex: 0,
            region: region,
            generation: currentGeneration,
            accumulatedItems: [],
            completion: completion
        )
    }


    // MARK: - Query Builder

    private func makeSearchQueries(
        for stop: FlexibleStop
    ) -> [String] {

        let detail =
            stop.query
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )


        let category =
            stop.category.title


        var queries: [String] = []


        /*
         IMPORTANT:

         We do NOT translate specific words.

         No:
         matcha → some hardcoded cafe

         No:
         ramen → some hardcoded restaurant

         We simply give MapKit multiple
         natural-language versions.
         */


        // MARK: User Input First

        if !detail.isEmpty {

            queries.append(
                detail
            )
        }


        // MARK: Input + Category Context

        if !detail.isEmpty {

            queries.append(
                "\(detail) \(category)"
            )
        }


        // MARK: Category Alone

        queries.append(
            category
        )


        /*
         Generic context.

         These are NOT specific businesses
         or locations.

         They simply help MapKit understand
         the type of POI the user wants.
         */

        switch stop.category {

        case .breakfast,
             .lunch,
             .dinner:

            if !detail.isEmpty {

                queries.append(
                    "\(detail) restaurant"
                )
            }


        case .coffee:

            if !detail.isEmpty {

                queries.append(
                    "\(detail) cafe"
                )
            }


        case .dessert:

            if !detail.isEmpty {

                queries.append(
                    "\(detail) dessert"
                )
            }


        case .drinks:

            if !detail.isEmpty {

                queries.append(
                    "\(detail) bar"
                )
            }


        case .shopping:

            if !detail.isEmpty {

                queries.append(
                    "\(detail) shopping"
                )
            }


        case .activity,
             .outdoors,
             .custom:

            break
        }


        return uniqueStrings(
            queries
        )
    }


    // MARK: - Sequential Search

    private func searchQueries(
        _ queries: [String],
        queryIndex: Int,
        region: MKCoordinateRegion?,
        generation: Int,
        accumulatedItems: [MKMapItem],
        completion:
            @escaping (
                Result<[MKMapItem], Error>
            ) -> Void
    ) {

        guard generation == self.generation else {
            return
        }


        // MARK: Finished All Queries

        guard queryIndex < queries.count else {

            let finalItems =
                removeDuplicates(
                    accumulatedItems
                )


            if finalItems.isEmpty {

                completion(
                    .failure(
                        FlexibleStopResolverError
                            .noResults(
                                queries.first
                                ??
                                "this stop"
                            )
                    )
                )

            } else {

                completion(
                    .success(
                        Array(
                            finalItems
                                .prefix(12)
                        )
                    )
                )
            }


            return
        }


        let query =
            queries[queryIndex]


        let request =
            MKLocalSearch.Request()


        request.naturalLanguageQuery =
            query


        if let region {

            request.region =
                region
        }


        let search =
            MKLocalSearch(
                request: request
            )


        activeSearches.append(
            search
        )


        search.start {
            [weak self]
            response,
            error in


            guard let self else {
                return
            }


            DispatchQueue.main.async {

                guard generation == self.generation else {
                    return
                }


                var updatedItems =
                    accumulatedItems


                if let error {

                    /*
                     THIS IS IMPORTANT.

                     One MapKit query failing
                     does NOT destroy the plan.

                     We log it and try the next
                     natural-language variant.
                     */

                    print(
                        """
                        🔎 Flexible search skipped
                        Query: \(query)
                        Error: \(error)
                        """
                    )

                } else {

                    let items =
                        response?
                            .mapItems
                        ??
                        []


                    updatedItems.append(
                        contentsOf:
                            items
                    )
                }


                /*
                 Stop early once we have
                 a healthy number of candidates.
                 */

                let unique =
                    self.removeDuplicates(
                        updatedItems
                    )


                if unique.count >= 10 {

                    completion(
                        .success(
                            Array(
                                unique
                                    .prefix(12)
                            )
                        )
                    )


                    return
                }


                self.searchQueries(
                    queries,
                    queryIndex:
                        queryIndex + 1,
                    region:
                        region,
                    generation:
                        generation,
                    accumulatedItems:
                        updatedItems,
                    completion:
                        completion
                )
            }
        }
    }


    // MARK: - Remove Duplicate Places

    private func removeDuplicates(
        _ items: [MKMapItem]
    ) -> [MKMapItem] {

        var seen:
            Set<String> = []


        var uniqueItems:
            [MKMapItem] = []


        for item in items {

            let coordinate =
                item.halfwayCoordinate


            let key =
                """
                \(normalize(item.name ?? ""))|
                \(String(format: "%.5f", coordinate.latitude))|
                \(String(format: "%.5f", coordinate.longitude))
                """


            guard !seen.contains(key) else {
                continue
            }


            seen.insert(
                key
            )


            uniqueItems.append(
                item
            )
        }


        return uniqueItems
    }


    // MARK: - String Helpers

    private func normalize(
        _ value: String
    ) -> String {

        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale: .current
            )
            .lowercased()
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
    }


    private func uniqueStrings(
        _ values: [String]
    ) -> [String] {

        var seen:
            Set<String> = []


        var output:
            [String] = []


        for value in values {

            let clean =
                value
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )


            guard !clean.isEmpty else {
                continue
            }


            let normalized =
                normalize(
                    clean
                )


            guard !seen.contains(
                normalized
            ) else {

                continue
            }


            seen.insert(
                normalized
            )


            output.append(
                clean
            )
        }


        return output
    }


    // MARK: - Cancel

    func cancel() {

        generation += 1


        for search in activeSearches {

            search.cancel()
        }


        activeSearches =
            []
    }
}
