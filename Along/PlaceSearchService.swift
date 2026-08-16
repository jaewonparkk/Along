import Foundation
import MapKit
import CoreLocation
import Combine


// MARK: - Search Result

struct PlaceSearchResult: Identifiable {

    let mapItem: MKMapItem
    let distanceMeters: CLLocationDistance?

    /// Original order returned by Apple's
    /// search completion system.
    let appleRank: Int


    var id: String {

        let coordinate =
            mapItem.alongCoordinate

        return """
        \(mapItem.name ?? "Unknown")|
        \(coordinate.latitude)|
        \(coordinate.longitude)
        """
    }
}


// MARK: - Place Search Service

final class PlaceSearchService:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate {

    // MARK: Published

    @Published
    var query: String = ""


    @Published private(set)
    var results: [PlaceSearchResult] = []


    @Published private(set)
    var isSearching = false


    @Published private(set)
    var referenceName =
        "Current Location"

    @Published private(set)
    var searchMessage: String?


    // MARK: Apple Search

    private let completer =
        MKLocalSearchCompleter()


    private var activeSearches:
        [MKLocalSearch] = []

    private var completionWorkItem:
        DispatchWorkItem?


    // MARK: Location Context

    private var currentRegion:
        MKCoordinateRegion?


    private var referenceLocation:
        CLLocation?


    // MARK: Combine

    private var cancellables =
        Set<AnyCancellable>()


    // MARK: Search Generation

    /*
     Every time the query changes,
     increase this number.

     Old async search results are ignored.
     */

    private var searchGeneration:
        Int = 0


    // MARK: Init

    override init() {

        super.init()


        completer.delegate =
            self


        /*
         We want:

         - actual places
         - addresses
         - query completions

         Query completions are important
         for things such as abbreviations,
         partial phrases, etc.
         */

        completer.resultTypes = [
            .pointOfInterest,
            .address,
            .query
        ]


        // MARK: Query Debounce

        $query
            .removeDuplicates()
            .debounce(
                for: .milliseconds(450),
                scheduler: DispatchQueue.main
            )
            .sink {
                [weak self]
                text in

                self?
                    .updateSearchQuery(
                        text
                    )
            }
            .store(
                in:
                    &cancellables
            )
    }


    // MARK: - Query

    private func updateSearchQuery(
        _ rawText: String
    ) {

        let text =
            rawText.trimmingCharacters(
                in:
                    CharacterSet
                        .whitespacesAndNewlines
            )


        searchGeneration += 1

        completionWorkItem?.cancel()


        cancelActiveSearches()


        guard text.count >= 1 else {

            completer.queryFragment =
                ""

            results =
                []

            isSearching =
                false

            return
        }


        isSearching =
            true

        searchMessage = nil


        /*
         IMPORTANT:

         Do NOT transform:
         "MFA" → "Museum of Fine Arts"

         Do NOT create acronym dictionaries.

         Give the user's actual text
         directly to Apple's search engine.
         */

        completer.queryFragment =
            text
    }


    // MARK: - Map Region

    func updateRegion(
        _ region: MKCoordinateRegion
    ) {

        currentRegion =
            region


        /*
         Apple uses the region as geographic
         search context.

         This region comes from the actual
         interactive map viewport.
         */

        completer.region =
            region


        /*
         Only use map center as distance
         reference if we have nothing better.
         */

        if referenceLocation == nil {

            referenceLocation =
                CLLocation(
                    latitude:
                        region.center.latitude,

                    longitude:
                        region.center.longitude
                )


            referenceName =
                "Map Center"
        }
    }


    // MARK: - Reference Location

    func setReference(
        place: PlannedPlace?,
        userLocation: CLLocation?
    ) {

        /*
         Priority:

         1. Last selected place
         2. User's location
         3. Visible map center
         */


        // MARK: Selected Place

        if let place {

            referenceLocation =
                CLLocation(
                    latitude:
                        place.coordinate.latitude,

                    longitude:
                        place.coordinate.longitude
                )


            referenceName =
                place.name


            recalculateDistances()

            return
        }


        // MARK: User Location

        if let userLocation {

            referenceLocation =
                userLocation


            referenceName =
                "Your Location"


            recalculateDistances()

            return
        }


        // MARK: Map Center

        if let currentRegion {

            referenceLocation =
                CLLocation(
                    latitude:
                        currentRegion.center.latitude,

                    longitude:
                        currentRegion.center.longitude
                )


            referenceName =
                "Map Center"


            recalculateDistances()

            return
        }


        referenceLocation =
            nil


        referenceName =
            "Current Location"
    }


    // MARK: - Completer Results

    func completerDidUpdateResults(
        _ completer:
            MKLocalSearchCompleter
    ) {

        let currentGeneration =
            searchGeneration


        let completions =
            Array(
                completer
                    .results
                    .prefix(5)
            )


        guard !completions.isEmpty else {

            completionWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                guard let self, currentGeneration == self.searchGeneration else { return }
                self.performFallbackSearch(generation: currentGeneration)
            }

            completionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)

            return
        }


        completionWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, currentGeneration == self.searchGeneration else { return }
            self.resolveCompletions(completions, generation: currentGeneration)
        }

        completionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }


    func completer(
        _ completer:
            MKLocalSearchCompleter,

        didFailWithError error:
            Error
    ) {

        print(
            "Search completion error:",
            error.localizedDescription
        )


        isSearching = false
        searchMessage = "Search is temporarily busy. Wait a moment and try again."
    }


    // MARK: - Resolve Apple Completions

    private func resolveCompletions(
        _ completions:
            [MKLocalSearchCompletion],

        generation:
            Int
    ) {

        cancelActiveSearches()


        isSearching =
            true


        let group =
            DispatchGroup()


        let lock =
            NSLock()


        var resolved:
            [PlaceSearchResult] = []


        for (
            index,
            completion
        ) in completions.enumerated() {

            group.enter()


            /*
             Convert Apple's completion
             into an actual map search.
             */

            let request =
                MKLocalSearch.Request(
                    completion:
                        completion
                )


            let search =
                MKLocalSearch(
                    request:
                        request
                )


            activeSearches.append(
                search
            )


            search.start {
                [weak self]
                response,
                error in


                defer {

                    group.leave()
                }


                guard let self else {
                    return
                }


                guard
                    generation
                    ==
                    self.searchGeneration

                else {

                    return
                }


                if let error {

                    print(
                        "Completion resolve error:",
                        error.localizedDescription
                    )

                    return
                }


                guard
                    let mapItem =
                        response?
                            .mapItems
                            .first

                else {

                    return
                }


                let distance =
                    self.distance(
                        to:
                            mapItem
                    )


                let result =
                    PlaceSearchResult(
                        mapItem:
                            mapItem,

                        distanceMeters:
                            distance,

                        appleRank:
                            index
                    )


                lock.lock()

                resolved.append(
                    result
                )

                lock.unlock()
            }
        }


        group.notify(
            queue:
                .main
        ) {
            [weak self] in


            guard let self else {
                return
            }


            guard
                generation
                ==
                self.searchGeneration

            else {

                return
            }


            self.activeSearches =
                []


            /*
             Preserve Apple's interpretation
             and ranking.

             Only use our distance ranking
             for multiple instances of the
             SAME place/business name.
             */

            self.results =
                self.organizeResults(
                    resolved
                )


            self.isSearching =
                false
        }
    }


    // MARK: - Organize Results

    private func organizeResults(
        _ rawResults:
            [PlaceSearchResult]
    ) -> [PlaceSearchResult] {

        let uniqueResults =
            removeDuplicates(
                rawResults
            )


        /*
         Group results by canonical name.

         Example:

         Tatte Bakery & Cafe
         Tatte Bakery & Cafe
         Tatte Bakery & Cafe

         becomes one group.

         But:

         Museum of Fine Arts
         MFA Duct Cleaning

         are NOT grouped together.
         */

        let grouped =
            Dictionary(
                grouping:
                    uniqueResults
            ) {
                result in

                normalizeName(
                    result
                        .mapItem
                        .name
                    ??
                    ""
                )
            }


        /*
         Apple's earliest result in each
         group determines group ranking.
         */

        let orderedGroups =
            grouped
                .values
                .sorted {
                    firstGroup,
                    secondGroup in


                    let firstRank =
                        firstGroup
                            .map(
                                \.appleRank
                            )
                            .min()
                        ??
                        Int.max


                    let secondRank =
                        secondGroup
                            .map(
                                \.appleRank
                            )
                            .min()
                        ??
                        Int.max


                    return firstRank
                        <
                        secondRank
                }


        var finalResults:
            [PlaceSearchResult] = []


        for group in orderedGroups {

            /*
             When Apple returned multiple
             branches of the same business,
             distance decides which branch
             appears first.
             */

            let sortedGroup =
                group.sorted {
                    first,
                    second in


                    let firstDistance =
                        first
                            .distanceMeters
                        ??
                        .greatestFiniteMagnitude


                    let secondDistance =
                        second
                            .distanceMeters
                        ??
                        .greatestFiniteMagnitude


                    return firstDistance
                        <
                        secondDistance
                }


            finalResults.append(
                contentsOf:
                    sortedGroup
            )
        }


        return finalResults
    }


    // MARK: - Remove Duplicates

    private func removeDuplicates(
        _ results:
            [PlaceSearchResult]
    ) -> [PlaceSearchResult] {

        var seen:
            Set<String> = []


        var unique:
            [PlaceSearchResult] = []


        let ordered =
            results.sorted {

                $0.appleRank
                <
                $1.appleRank
            }


        for result in ordered {

            let coordinate =
                result
                    .mapItem
                    .alongCoordinate


            let key =
                """
                \(normalizeName(result.mapItem.name ?? ""))|
                \(String(format: "%.5f", coordinate.latitude))|
                \(String(format: "%.5f", coordinate.longitude))
                """


            if !seen.contains(
                key
            ) {

                seen.insert(
                    key
                )


                unique.append(
                    result
                )
            }
        }


        return unique
    }


    // MARK: - Fallback Search

    private func performFallbackSearch(
        generation:
            Int
    ) {

        let trimmedQuery =
            query.trimmingCharacters(
                in:
                    CharacterSet
                        .whitespacesAndNewlines
            )


        guard !trimmedQuery.isEmpty else {

            results =
                []

            isSearching =
                false

            return
        }


        cancelActiveSearches()


        let request =
            MKLocalSearch.Request()


        request.naturalLanguageQuery =
            trimmedQuery


        if #available(iOS 18.0, *) {

            request.resultTypes = [
                .pointOfInterest,
                .address,
                .physicalFeature
            ]

        } else {

            request.resultTypes = [
                .pointOfInterest,
                .address
            ]
        }


        if let currentRegion {

            request.region =
                currentRegion
        }


        let search =
            MKLocalSearch(
                request:
                    request
            )


        activeSearches =
            [search]


        search.start {
            [weak self]
            response,
            error in


            guard let self else {
                return
            }


            DispatchQueue.main.async {

                guard
                    generation
                    ==
                    self.searchGeneration

                else {

                    return
                }


                self.activeSearches =
                    []


                self.isSearching =
                    false


                if let error {

                    print(
                        "Fallback search error:",
                        error.localizedDescription
                    )


                    self.results =
                        []

                    return
                }


                let mapItems =
                    response?
                        .mapItems
                    ??
                    []


                let converted =
                    mapItems
                        .prefix(12)
                        .enumerated()
                        .map {
                            index,
                            mapItem in


                            PlaceSearchResult(
                                mapItem:
                                    mapItem,

                                distanceMeters:
                                    self.distance(
                                        to:
                                            mapItem
                                    ),

                                appleRank:
                                    index
                            )
                        }


                self.results =
                    self.organizeResults(
                        converted
                    )
            }
        }
    }


    // MARK: - Distance

    private func distance(
        to mapItem:
            MKMapItem
    ) -> CLLocationDistance? {

        guard
            let referenceLocation

        else {

            return nil
        }


        let coordinate =
            mapItem
                .alongCoordinate


        let destination =
            CLLocation(
                latitude:
                    coordinate.latitude,

                longitude:
                    coordinate.longitude
            )


        return referenceLocation
            .distance(
                from:
                    destination
            )
    }


    // MARK: - Recalculate Existing Distances

    private func recalculateDistances() {

        guard !results.isEmpty else {
            return
        }


        let updated =
            results.map {
                result in


                PlaceSearchResult(
                    mapItem:
                        result.mapItem,

                    distanceMeters:
                        distance(
                            to:
                                result.mapItem
                        ),

                    appleRank:
                        result.appleRank
                )
            }


        results =
            organizeResults(
                updated
            )
    }


    // MARK: - Name Normalization

    private func normalizeName(
        _ value: String
    ) -> String {

        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],

                locale:
                    .current
            )
            .lowercased()
            .components(
                separatedBy:
                    CharacterSet
                        .alphanumerics
                        .inverted
            )
            .filter {
                !$0.isEmpty
            }
            .joined(
                separator:
                    " "
            )
    }


    // MARK: - Cancel

    private func cancelActiveSearches() {

        for search in activeSearches {

            search.cancel()
        }


        activeSearches =
            []
    }


    // MARK: - Clear

    func clear() {

        searchGeneration += 1

        completionWorkItem?.cancel()
        completionWorkItem = nil


        cancelActiveSearches()


        completer.queryFragment =
            ""


        query =
            ""


        results =
            []


        isSearching =
            false

        searchMessage = nil
    }
}
