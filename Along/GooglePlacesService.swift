import Foundation
import CoreLocation
import MapKit
import GooglePlaces


// MARK: - Google Places Service Error

enum GooglePlacesServiceError:
    LocalizedError {

    case noResults(String)


    var errorDescription: String? {

        switch self {

        case .noResults(
            let query
        ):

            return
                "No real places were found for “\(query)”."
        }
    }
}


// MARK: - Google Places Service

@MainActor
final class GooglePlacesService {

    // MARK: Singleton

    static let shared =
        GooglePlacesService()


    // MARK: Client

    private let client =
        GMSPlacesClient.shared()


    private init() {}


    // MARK: - Fields

    private var requestedProperties:
        [String] {

        /*
         Opening-hour fields are included up front
         so we do not have to repeatedly fetch
         details for every candidate.
         */

        [
            GMSPlaceProperty.name,
            GMSPlaceProperty.placeID,
            GMSPlaceProperty.coordinate,
            GMSPlaceProperty.formattedAddress,
            GMSPlaceProperty.rating,
            GMSPlaceProperty.types,
            GMSPlaceProperty.photos,

            GMSPlaceProperty.businessStatus,
            GMSPlaceProperty.utcOffsetMinutes,

            GMSPlaceProperty.openingHours,
            GMSPlaceProperty.currentOpeningHours,
            GMSPlaceProperty.secondaryOpeningHours
        ]
        .map {
            $0.rawValue
        }
    }

    func detail(
        for place: PlannedPlace
    ) async -> PlaceDetailData {
        let candidate = await enrich(anchor: place)

        guard let googlePlace = candidate.googlePlace else {
            return PlaceDetailData(
                photo: nil,
                todayHours: nil,
                openStatus: .unknown,
                suggestedCategory: nil
            )
        }

        let status = await openStatus(place: googlePlace, at: Date())
        let weekday = Date().formatted(.dateTime.weekday(.wide))
        let hours = (googlePlace.currentOpeningHours?.weekdayText
                     ?? googlePlace.openingHours?.weekdayText)?
            .first {
                $0.range(
                    of: weekday,
                    options: [.anchored, .caseInsensitive, .diacriticInsensitive]
                ) != nil
            }

        var photo: UIImage?
        if let metadata = googlePlace.photos?.first {
            let request = GMSFetchPhotoRequest(
                photoMetadata: metadata,
                maxSize: CGSize(width: 1200, height: 700)
            )

            photo = await withCheckedContinuation { continuation in
                client.fetchPhoto(with: request) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }

        return PlaceDetailData(
            photo: photo,
            todayHours: hours,
            openStatus: PlaceDetailOpenStatus(status),
            suggestedCategory: suggestedCategory(for: googlePlace.types ?? [])
        )
    }

    private func suggestedCategory(for types: [String]) -> FlexibleStopCategory? {
        let values = Set(types.map { $0.lowercased() })

        if !values.isDisjoint(with: ["cafe", "coffee_shop"]) { return .coffee }
        if !values.isDisjoint(with: ["bakery", "dessert_shop", "ice_cream_shop"]) { return .dessert }
        if !values.isDisjoint(with: ["bar", "night_club", "wine_bar"]) { return .drinks }
        if !values.isDisjoint(with: ["restaurant", "food", "meal_takeaway", "meal_delivery"]) { return .food }
        if !values.isDisjoint(with: ["store", "shopping_mall", "clothing_store", "book_store"]) { return .shopping }
        if !values.isDisjoint(with: ["park", "campground", "natural_feature"]) { return .outdoors }
        if !values.isDisjoint(with: ["museum", "aquarium", "art_gallery", "tourist_attraction", "amusement_park"]) { return .activity }
        return nil
    }


    // MARK: - Text Search

    func search(
        text: String,
        center: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) async throws -> [PlaceCandidate] {

        let cleanQuery =
            text.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )


        guard !cleanQuery.isEmpty else {

            return []
        }


        let request =
            GMSPlaceSearchByTextRequest(
                textQuery:
                    cleanQuery,

                placeProperties:
                    requestedProperties
            )


        /*
         Google allows 1...20 Text Search results.
         We want enough alternatives for
         the planner without going crazy.
         */

        request.maxResultCount =
            20


        /*
         Bias, NOT restriction.

         A very good option slightly outside
         the radius can still be returned.
         */

        request.locationBias =
            GMSPlaceCircularLocationOption(
                center,

                min(
                    50_000,
                    max(
                        500,
                        radiusMeters
                    )
                )
            )


        request.isOpenNow =
            false


        let response =
            try await client.searchByText(
                with:
                    request
            )


        let places =
            response.places
            ??
            []


        return places
            .enumerated()
            .compactMap {
                index,
                googlePlace in


                /*
                 Never intentionally suggest
                 businesses Google says are
                 permanently/temporarily closed.
                 */

                switch googlePlace
                    .businessStatus {

                case .closedPermanently,
                     .closedTemporarily:

                    return nil


                case .operational,
                     .unknown:

                    break


                @unknown default:

                    break
                }


                let plannedPlace =
                    makePlannedPlace(
                        from:
                            googlePlace
                    )


                return PlaceCandidate(
                    plannedPlace:
                        plannedPlace,

                    googlePlace:
                        googlePlace,

                    searchRank:
                        index
                )
            }
    }


    // MARK: - Enrich Existing Anchor

    func enrich(
        anchor:
            PlannedPlace
    ) async -> PlaceCandidate {

        /*
         Anchors originally come from Apple Maps.

         We do NOT replace the anchor.

         We only search Google near its exact
         coordinate to attach opening-hours
         metadata.
         */

        var components:
            [String] = [
                anchor.name
            ]


        let appleAddress =
            anchor
                .mapItem
                .alongAddressText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        if !appleAddress.isEmpty {

            components.append(
                appleAddress
            )
        }


        let query =
            components.joined(
                separator:
                    " "
            )


        do {

            let results =
                try await search(
                    text:
                        query,

                    center:
                        anchor.coordinate,

                    radiusMeters:
                        2_000
                )


            guard !results.isEmpty else {

                return PlaceCandidate(
                    plannedPlace:
                        anchor,

                    googlePlace:
                        nil,

                    searchRank:
                        0
                )
            }


            /*
             Since we already know the exact
             Apple Maps coordinate, choose the
             Google result closest to it.
             */

            let anchorLocation =
                CLLocation(
                    latitude:
                        anchor
                            .coordinate
                            .latitude,

                    longitude:
                        anchor
                            .coordinate
                            .longitude
                )


            let bestMatch =
                results.min {
                    first,
                    second in


                    distance(
                        from:
                            first,
                        to:
                            anchorLocation
                    )
                    <
                    distance(
                        from:
                            second,
                        to:
                            anchorLocation
                    )
                }


            return PlaceCandidate(
                plannedPlace:
                    anchor,

                googlePlace:
                    bestMatch?
                        .googlePlace,

                searchRank:
                    0
            )

        } catch {

            print(
                """
                ⚠️ Could not enrich anchor hours
                \(anchor.name)
                \(error.localizedDescription)
                """
            )


            /*
             Important:

             Don't delete the anchor merely
             because metadata lookup failed.
             */

            return PlaceCandidate(
                plannedPlace:
                    anchor,

                googlePlace:
                    nil,

                searchRank:
                    0
            )
        }
    }


    // MARK: - Opening Hours Constraint

    func availability(
        for candidate:
            PlaceCandidate,

        from start:
            Date,

        until end:
            Date
    ) async -> PlaceHoursAvailability {

        guard end > start else {

            return .unknown
        }


        guard let place =
                candidate.googlePlace
        else {

            return .unknown
        }


        switch place.businessStatus {

        case .closedPermanently,
             .closedTemporarily:

            return .closed


        case .operational,
             .unknown:

            break


        @unknown default:

            break
        }


        /*
         Google specifically recommends checking
         whether opening-hours data exists before
         calling isOpen.

         If Google has NO hour data, we keep it
         as unknown rather than inventing hours.
         */

        guard
            place.currentOpeningHours != nil
            ||
            place.openingHours != nil
        else {

            return .unknown
        }


        /*
         To ensure:

         3:30 arrival
         museum closes 4:00
         60-minute visit

         does NOT get accepted,

         check both the start and almost the end
         of the visit.
         */

        let endProbe =
            end.addingTimeInterval(
                -60
            )


        var probes:
            [Date] = [
                start,
                max(
                    start,
                    endProbe
                )
            ]


        /*
         For unusually long visits,
         also verify the middle.
         */

        if end.timeIntervalSince(
            start
        )
        >
        2 * 60 * 60 {

            let middle =
                start.addingTimeInterval(
                    end.timeIntervalSince(
                        start
                    )
                    /
                    2
                )


            probes.insert(
                middle,
                at:
                    1
            )
        }


        var sawUnknown =
            false


        for date in probes {

            let status =
                await openStatus(
                    place:
                        place,

                    at:
                        date
                )


            switch status {

            case .open:

                continue


            case .closed:

                return .closed


            case .unknown:

                sawUnknown =
                    true


            @unknown default:

                sawUnknown =
                    true
            }
        }


        return sawUnknown
        ?
        .unknown
        :
        .open
    }


    // MARK: - Individual Open Status

    private func openStatus(
        place:
            GMSPlace,

        at date:
            Date
    ) async -> GMSPlaceOpenStatus {

        await withCheckedContinuation {
            continuation in


            let request =
                GMSPlaceIsOpenRequest(
                    place:
                        place,

                    date:
                        date
                )


            client.isOpen(
                with:
                    request
            ) {
                response,
                error in


                if let error {

                    print(
                        """
                        🕒 Google hours lookup unavailable
                        \(place.name ?? "Unknown")
                        \(error.localizedDescription)
                        """
                    )


                    continuation.resume(
                        returning:
                            .unknown
                    )


                    return
                }


                continuation.resume(
                    returning:
                        response.status
                )
            }
        }
    }


    // MARK: - GMSPlace → PlannedPlace

    private func makePlannedPlace(
        from googlePlace:
            GMSPlace
    ) -> PlannedPlace {

        let location =
            CLLocation(
                latitude:
                    googlePlace
                        .coordinate
                        .latitude,

                longitude:
                    googlePlace
                        .coordinate
                        .longitude
            )


        let mapItem:
            MKMapItem


        if #available(
            iOS 26.0,
            *
        ) {

            mapItem =
                MKMapItem(
                    location:
                        location,

                    address:
                        nil
                )

        } else {

            mapItem =
                MKMapItem(
                    placemark:
                        MKPlacemark(
                            coordinate:
                                googlePlace
                                    .coordinate
                        )
                )
        }


        mapItem.name =
            googlePlace.name
            ??
            "Unnamed Place"


        return PlannedPlace(
            mapItem:
                mapItem
        )
    }


    // MARK: - Distance

    private func distance(
        from candidate:
            PlaceCandidate,

        to reference:
            CLLocation
    ) -> CLLocationDistance {

        CLLocation(
            latitude:
                candidate
                    .plannedPlace
                    .coordinate
                    .latitude,

            longitude:
                candidate
                    .plannedPlace
                    .coordinate
                    .longitude
        )
        .distance(
            from:
                reference
        )
    }
}
