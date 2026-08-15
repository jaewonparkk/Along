import SwiftUI
import MapKit
import CoreLocation


struct ItineraryResultView: View {

    // MARK: - Data

    let itinerary: GeneratedItinerary

    let routeLegs: [RouteLeg]

    let totalTravelTime: TimeInterval

    let totalDistance: CLLocationDistance

    let travelMode: TravelMode

    let hasCurrentLocation: Bool


    // MARK: - Actions

    let onEdit: () -> Void


    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss


    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    heroSection

                    summaryCard

                    itinerarySection

                    bottomActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .navigationTitle("Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button("Done") {

                        dismiss()
                    }
                }
            }
        }
    }


    // MARK: - Hero

    private var heroSection: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack(spacing: 8) {

                Image(
                    systemName: "wand.and.stars"
                )

                Text("Halfway built your route")
                    .font(
                        .title2.bold()
                    )
            }


            Text(
                "\(itinerary.orderedPlaces.count) stops arranged around your route."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Summary

    private var summaryCard: some View {

        HStack(spacing: 0) {

            summaryMetric(
                icon: travelMode.icon,
                value: formatTime(totalTravelTime),
                label: "Travel"
            )


            Divider()
                .frame(height: 46)


            summaryMetric(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                value: formatDistance(totalDistance),
                label: "Distance"
            )


            Divider()
                .frame(height: 46)


            summaryMetric(
                icon: "mappin.and.ellipse",
                value: "\(itinerary.orderedPlaces.count)",
                label: "Stops"
            )
        }
        .padding(.vertical, 18)
        .background(
            Color.primary.opacity(0.055)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }


    private func summaryMetric(
        icon: String,
        value: String,
        label: String
    ) -> some View {

        VStack(spacing: 5) {

            Image(
                systemName: icon
            )
            .font(.headline)


            Text(value)
                .font(
                    .subheadline.bold()
                )


            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity
        )
    }


    // MARK: - Itinerary

    private var itinerarySection: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            Text("ITINERARY")
                .font(
                    .caption.bold()
                )
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)


            // MARK: Current Location

            if hasCurrentLocation {

                startLocationRow


                if let firstLeg =
                    routeLegForFirstStop {

                    connector(
                        leg: firstLeg
                    )
                }
            }


            // MARK: Stops

            ForEach(
                Array(
                    itinerary
                        .orderedPlaces
                        .enumerated()
                ),
                id: \.element.id
            ) { index, place in

                placeRow(
                    place: place,
                    number: index + 1
                )


                if index <
                    itinerary.orderedPlaces.count - 1 {

                    if let leg =
                        routeLeg(
                            to:
                                itinerary
                                    .orderedPlaces[
                                        index + 1
                                    ]
                        ) {

                        connector(
                            leg: leg
                        )

                    } else {

                        emptyConnector
                    }
                }
            }
        }
    }


    // MARK: - Current Location Row

    private var startLocationRow: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.primary.opacity(0.09)
                    )
                    .frame(
                        width: 42,
                        height: 42
                    )


                Image(
                    systemName: "location.fill"
                )
                .font(.system(size: 16))
            }


            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("Start")
                    .font(
                        .caption
                            .weight(.semibold)
                    )
                    .foregroundStyle(.secondary)


                Text("Current Location")
                    .font(
                        .body
                            .weight(.semibold)
                    )
            }


            Spacer()
        }
    }


    // MARK: - Place Row

    private func placeRow(
        place: PlannedPlace,
        number: Int
    ) -> some View {

        let resolved =
            resolvedStop(
                for: place
            )


        return HStack(
            alignment: .top,
            spacing: 14
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.accentColor
                    )
                    .frame(
                        width: 42,
                        height: 42
                    )


                Text(
                    "\(number)"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
            }


            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(place.name)
                    .font(
                        .body.weight(.semibold)
                    )


                if let resolved {

                    flexibleStopDescription(
                        resolved
                    )

                } else {

                    HStack(spacing: 5) {

                        Image(
                            systemName: "heart.fill"
                        )
                        .font(.caption2)


                        Text("Must visit")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }


                let address =
                    place
                        .mapItem
                        .halfwayAddressText


                if !address.isEmpty {

                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }


            Spacer()
        }
    }


    // MARK: - Flexible Stop Description

    private func flexibleStopDescription(
        _ resolved: ResolvedFlexibleStop
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            HStack(spacing: 5) {

                Image(
                    systemName:
                        resolved
                            .source
                            .category
                            .icon
                )
                .font(.caption2)


                Text(
                    resolved
                        .source
                        .category
                        .title
                )
                .font(
                    .caption
                        .weight(.medium)
                )


                let query =
                    resolved
                        .source
                        .query
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )


                if !query.isEmpty {

                    Text("•")

                    Text(query)
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)


            HStack(spacing: 5) {

                Image(
                    systemName:
                        "arrow.triangle.branch"
                )
                .font(.system(size: 9))


                Text(
                    "About +\(formatTime(resolved.addedTravelTime)) of travel"
                )
                .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        }
    }


    // MARK: - Connector

    private func connector(
        leg: RouteLeg
    ) -> some View {

        HStack(
            alignment: .center,
            spacing: 14
        ) {

            VStack(spacing: 0) {

                Rectangle()
                    .fill(
                        Color.secondary.opacity(0.25)
                    )
                    .frame(
                        width: 2,
                        height: 13
                    )


                Image(
                    systemName: travelMode.icon
                )
                .font(
                    .system(size: 11)
                )
                .foregroundStyle(.secondary)
                .padding(.vertical, 5)


                Rectangle()
                    .fill(
                        Color.secondary.opacity(0.25)
                    )
                    .frame(
                        width: 2,
                        height: 13
                    )
            }
            .frame(width: 42)


            HStack {

                Text(
                    formatTime(
                        leg.travelTime
                    )
                )


                Text("•")


                Text(
                    formatDistance(
                        leg.distance
                    )
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)


            Spacer()
        }
    }


    private var emptyConnector: some View {

        HStack(spacing: 14) {

            Rectangle()
                .fill(
                    Color.secondary.opacity(0.2)
                )
                .frame(
                    width: 2,
                    height: 32
                )
                .frame(width: 42)


            Spacer()
        }
    }


    // MARK: - Actions

    private var bottomActions: some View {

        VStack(spacing: 10) {

            Button {

                dismiss()

            } label: {

                HStack {

                    Spacer()


                    Image(
                        systemName: "map.fill"
                    )


                    Text("View on Map")
                        .font(.headline)


                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(
                .borderedProminent
            )


            Button {

                dismiss()


                DispatchQueue.main.asyncAfter(
                    deadline:
                        .now() + 0.25
                ) {

                    onEdit()
                }

            } label: {

                HStack {

                    Spacer()


                    Image(
                        systemName: "pencil"
                    )


                    Text("Edit Plan")
                        .font(.headline)


                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
    }


    // MARK: - Resolved Stop Lookup

    private func resolvedStop(
        for place: PlannedPlace
    ) -> ResolvedFlexibleStop? {

        itinerary
            .resolvedFlexibleStops
            .first {

                $0.place.id ==
                    place.id
            }
    }


    // MARK: - Route Lookup

    private var routeLegForFirstStop:
        RouteLeg? {

        guard let firstPlace =
                itinerary
                    .orderedPlaces
                    .first
        else {

            return nil
        }


        return routeLegs.first {

            $0.toPlaceID ==
                firstPlace.id
            &&
            $0.fromPlaceID == nil
        }
    }


    private func routeLeg(
        to place: PlannedPlace
    ) -> RouteLeg? {

        routeLegs.first {

            $0.toPlaceID ==
                place.id
        }
    }


    // MARK: - Formatting

    private func formatTime(
        _ seconds: TimeInterval
    ) -> String {

        let minutes =
            max(
                1,
                Int(
                    round(
                        seconds / 60
                    )
                )
            )


        if minutes < 60 {

            return "\(minutes) min"
        }


        let hours =
            minutes / 60


        let remainder =
            minutes % 60


        if remainder == 0 {

            return "\(hours) hr"
        }


        return "\(hours) hr \(remainder) min"
    }


    private func formatDistance(
        _ meters: CLLocationDistance
    ) -> String {

        if meters < 1000 {

            return "\(Int(meters.rounded())) m"
        }


        return String(
            format: "%.1f km",
            meters / 1000
        )
    }
}
