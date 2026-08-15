import Foundation
import MapKit


enum FlexibleStopResolverError:
    LocalizedError {

    case noResults(String)


    var errorDescription:
        String? {

        switch self {

        case .noResults(
            let query
        ):

            return "No places were found for “\(query)”."
        }
    }
}


// MARK: - Flexible Stop Resolver

final class FlexibleStopResolver {

    private var activeSearch:
        MKLocalSearch?


    // MARK: - Search

    func searchCandidates(
        for stop:
            FlexibleStop,

        region:
            MKCoordinateRegion?,

        completion:
            @escaping (
                Result<
                    [MKMapItem],
                    Error
                >
            ) -> Void
    ) {

        activeSearch?
            .cancel()


        let searchText =
            makeSearchText(
                for: stop
            )


        let request =
            MKLocalSearch.Request()


        /*
         No restaurant names.
         No Boston-specific query.
         No coordinates.

         The search phrase comes entirely
         from the user's flexible stop.
         */

        request.naturalLanguageQuery =
            searchText


        /*
         Let MapKit decide the result types.

         This lets a flexible stop potentially
         resolve to businesses, activities,
         parks, etc.
         */

        if let region {

            request.region =
                region
        }


        let search =
            MKLocalSearch(
                request:
                    request
            )


        activeSearch =
            search


        search.start {
            [weak self]
            response,
            error in


            DispatchQueue.main.async {

                self?.activeSearch =
                    nil


                if let error {

                    completion(
                        .failure(
                            error
                        )
                    )

                    return
                }


                let rawItems =
                    response?
                        .mapItems
                    ??
                    []


                let uniqueItems =
                    self?
                        .removeDuplicates(
                            rawItems
                        )
                    ??
                    []


                guard !uniqueItems.isEmpty else {

                    completion(
                        .failure(
                            FlexibleStopResolverError
                                .noResults(
                                    searchText
                                )
                        )
                    )

                    return
                }


                /*
                 Preserve Apple's search
                 relevance order.

                 PlanningEngine will compare
                 route fit afterward.
                 */

                completion(
                    .success(
                        Array(
                            uniqueItems
                                .prefix(10)
                        )
                    )
                )
            }
        }
    }


    // MARK: - Search Text

    private func makeSearchText(
        for stop:
            FlexibleStop
    ) -> String {

        let detail =
            stop.query
                .trimmingCharacters(
                    in:
                        CharacterSet
                            .whitespacesAndNewlines
                )


        if detail.isEmpty {

            return stop
                .category
                .title
        }


        return "\(detail) \(stop.category.title)"
    }


    // MARK: - Deduplicate

    private func removeDuplicates(
        _ items:
            [MKMapItem]
    ) -> [MKMapItem] {

        var seen:
            Set<String> = []


        var output:
            [MKMapItem] = []


        for item in items {

            let coordinate =
                item
                    .halfwayCoordinate


            let key =
                """
                \(normalized(item.name ?? ""))|
                \(String(format: "%.5f", coordinate.latitude))|
                \(String(format: "%.5f", coordinate.longitude))
                """


            if !seen.contains(
                key
            ) {

                seen.insert(
                    key
                )


                output.append(
                    item
                )
            }
        }


        return output
    }


    // MARK: - Normalize

    private func normalized(
        _ string: String
    ) -> String {

        string
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],

                locale:
                    .current
            )
            .lowercased()
    }


    // MARK: - Cancel

    func cancel() {

        activeSearch?
            .cancel()


        activeSearch =
            nil
    }
}
