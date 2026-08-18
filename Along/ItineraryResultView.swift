import SwiftUI
import MapKit
import CoreLocation
import SwiftData


struct ItineraryResultView: View {

    // MARK: - Data

    let itinerary:
        GeneratedItinerary


    let routeLegs:
        [RouteLeg]


    let totalTravelTime:
        TimeInterval


    let totalDistance:
        CLLocationDistance


    let travelMode:
        TravelMode


    let hasCurrentLocation:
        Bool

    let finishBy:
        Date

    let suggestedPlaceIDs:
        Set<UUID>

    let onAddSuggestedStop:
        (RouteSuggestion) -> Void


    let onEdit:
        () -> Void


    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \SavedPlace.savedAt, order: .reverse)
    private var savedPlaces: [SavedPlace]

    @StateObject
    private var suggestionService = RouteSuggestionService()

    @State
    private var selectedPlace: PlannedPlace?

    @State
    private var isSavePromptPresented = false

    @State
    private var didSave = false


    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        24
                ) {

                    heroSection

                    summaryCard

                    itinerarySection

                    if remainingTime >= 60 * 60 {
                        earlyFinishCard
                    }

                    bottomActions
                }
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .top,
                    18
                )
                .padding(
                    .bottom,
                    40
                )
            }
            .navigationTitle(
                "Your Day"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button("Done") {

                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(
                place: place,
                scheduled: scheduledStop(for: place)
            )
        }
        .sheet(isPresented: $isSavePromptPresented) {
            SaveDayPrompt(defaultTitle: defaultSavedTitle) { title in
                saveDay(title: title)
            }
        }
    }

    private var remainingTime: TimeInterval {
        guard let finish = itinerary.estimatedFinishTime else { return 0 }
        return max(0, finishBy.timeIntervalSince(finish))
    }

    private var earlyFinishCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                "You have \(formatTime(remainingTime)) left",
                systemImage: "sparkles"
            )
            .font(.headline)

            Text("Your plan ends earlier than you wanted. Want to see places that fit along this route?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                suggestionButton(.food)
                suggestionButton(.coffee)
                suggestionButton(.shopping)
                suggestionButton(.activity)
            }

            if suggestionService.isLoading {
                HStack {
                    ProgressView()
                    Text("Finding places along your route...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let message = suggestionService.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !suggestionService.suggestions.isEmpty {
                Divider()
                ForEach(suggestionService.suggestions) { suggestion in
                    Button {
                        onAddSuggestedStop(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.category.icon)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.mapItem.name ?? "Suggested place")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if suggestion.isSaved {
                                    Label("Saved to Along", systemImage: "heart.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.pink)
                                }
                                Text("Fits between stops • about \(formatDistance(suggestion.addedDistance)) extra")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func suggestionButton(_ category: FlexibleStopCategory) -> some View {
        Button {
            suggestionService.search(
                category: category,
                along: itinerary.orderedPlaces,
                savedPlaces: savedPlaces.map(\.snapshot)
            )
        } label: {
            Label(category.title, systemImage: category.icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }


    // MARK: - Hero

    private var heroSection:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                8
        ) {

            HStack(
                spacing:
                    8
            ) {

                Image(
                    systemName:
                        "wand.and.stars"
                )


                Text(
                    "Along built your day"
                )
                .font(
                    .title2.bold()
                )
            }


            if let finish =
                itinerary
                    .estimatedFinishTime {

                Text(
                    "Estimated finish: \(formatClock(finish))"
                )
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )
            }


            if itinerary
                .hasTimingConflicts {

                Label(
                    "One or more stops need your attention.",
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }


    // MARK: - Summary

    private var summaryCard:
        some View {

        HStack(
            spacing:
                0
        ) {

            summaryMetric(
                icon:
                    travelMode.icon,
                value:
                    formatTime(
                        totalTravelTime
                    ),
                label:
                    "Travel"
            )


            Divider()
                .frame(
                    height:
                        46
                )


            summaryMetric(
                icon:
                    "point.topleft.down.to.point.bottomright.curvepath",
                value:
                    formatDistance(
                        totalDistance
                    ),
                label:
                    "Distance"
            )


            Divider()
                .frame(
                    height:
                        46
                )


            summaryMetric(
                icon:
                    "mappin.and.ellipse",
                value:
                    "\(itinerary.orderedPlaces.count)",
                label:
                    "Stops"
            )
        }
        .padding(
            .vertical,
            18
        )
        .background(
            Color.primary
                .opacity(
                    0.055
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    20,
                style:
                    .continuous
            )
        )
    }


    private func summaryMetric(
        icon: String,
        value: String,
        label: String
    ) -> some View {

        VStack(
            spacing:
                5
        ) {

            Image(
                systemName:
                    icon
            )
            .font(
                .headline
            )


            Text(
                value
            )
            .font(
                .subheadline.bold()
            )


            Text(
                label
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
    }


    // MARK: - Itinerary

    private var itinerarySection:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                0
        ) {

            Text(
                "ITINERARY"
            )
            .font(
                .caption.bold()
            )
            .foregroundStyle(
                .secondary
            )
            .padding(
                .bottom,
                16
            )


            // MARK: Start

            if hasCurrentLocation {

                startLocationRow


                if let first =
                    itinerary
                        .orderedPlaces
                        .first {

                    routeConnector(
                        to:
                            first
                    )
                }
            }


            // MARK: Places

            ForEach(
                Array(
                    itinerary
                        .orderedPlaces
                        .enumerated()
                ),
                id:
                    \.element.id
            ) {
                index,
                place in


                placeRow(
                    place:
                        place,
                    number:
                        index + 1
                )


                if index <
                    itinerary
                        .orderedPlaces
                        .count
                    -
                    1 {

                    let next =
                        itinerary
                            .orderedPlaces[
                                index + 1
                            ]


                    routeConnector(
                        to:
                            next
                    )
                }
            }
        }
    }


    // MARK: - Start Row

    private var startLocationRow:
        some View {

        HStack(
            alignment:
                .top,
            spacing:
                14
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.primary
                            .opacity(
                                0.09
                            )
                    )
                    .frame(
                        width:
                            42,
                        height:
                            42
                    )


                Image(
                    systemName:
                        "location.fill"
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "Start"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )
                .foregroundStyle(
                    .secondary
                )


                Text(
                    "Current Location"
                )
                .font(
                    .body
                        .weight(
                            .semibold
                        )
                )
            }


            Spacer()
        }
    }


    // MARK: - Place Row

    private func placeRow(
        place:
            PlannedPlace,
        number:
            Int
    ) -> some View {

        let resolved =
            resolvedStop(
                for:
                    place
            )


        let scheduled =
            scheduledStop(
                for:
                    place
            )


        return HStack(
            alignment:
                .top,
            spacing:
                14
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.accentColor
                    )
                    .frame(
                        width:
                            42,
                        height:
                            42
                    )


                Text(
                    "\(number)"
                )
                .font(
                    .system(
                        size:
                            14,
                        weight:
                            .bold
                    )
                )
                .foregroundStyle(
                    .white
                )
            }


            VStack(
                alignment:
                    .leading,
                spacing:
                    6
            ) {

                if let scheduled {

                    Text(
                        "\(formatClock(scheduled.startTime))–\(formatClock(scheduled.departureTime)) • \(formatTime(scheduled.departureTime.timeIntervalSince(scheduled.startTime))) stay"
                    )
                    .font(
                        .caption.bold()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }


                Text(
                    place.name
                )
                .font(
                    .body
                        .weight(
                            .semibold
                        )
                )

                if isSavedPlace(place) {
                    Label("Saved to Along", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                }


                if let resolved {

                    flexibleDescription(
                        resolved,
                        scheduled:
                            scheduled
                    )

                } else {

                    Label(
                        suggestedPlaceIDs.contains(place.id)
                        ? "Added along your route"
                        : "Must visit",
                        systemImage:
                            suggestedPlaceIDs.contains(place.id)
                            ? "sparkles"
                            : "heart.fill"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                if let warning = scheduled?.warning {
                    Label(
                        warning,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }


                let address =
                    place
                        .mapItem
                        .alongAddressText


                if !address.isEmpty {

                    Text(
                        address
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                    .lineLimit(
                        2
                    )
                }
            }


            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedPlace = place
        }
    }


    // MARK: - Flexible Description

    private func flexibleDescription(
        _ resolved:
            ResolvedFlexibleStop,
        scheduled:
            ScheduledStop?
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {

            HStack(
                spacing:
                    5
            ) {

                Image(
                    systemName:
                        resolved
                            .source
                            .category
                            .icon
                )
                .font(
                    .caption2
                )


                Text(
                    resolved
                        .source
                        .category
                        .title
                )
                .font(
                    .caption
                        .weight(
                            .medium
                        )
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
                        .font(
                            .caption
                        )
                }
            }
            .foregroundStyle(
                .secondary
            )


            if let scheduled,
               let timing =
                scheduled
                    .requestedTiming {

                timingStatusRow(
                    scheduled:
                        scheduled,
                    timing:
                        timing
                )
            }


            if resolved
                .addedTravelTime
                >
                0.5 {

                Label(
                    "About +\(formatTime(resolved.addedTravelTime)) travel",
                    systemImage:
                        "arrow.triangle.branch"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )

            } else {

                Label(
                    "Best nearby match",
                    systemImage:
                        "location.magnifyingglass"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
            }
        }
    }

    private func isSavedPlace(_ place: PlannedPlace) -> Bool {
        let key = SavedPlace.key(for: place)
        return savedPlaces.contains { $0.placeKey == key }
    }


    // MARK: - Timing

    @ViewBuilder
    private func timingStatusRow(
        scheduled:
            ScheduledStop,
        timing:
            String
    ) -> some View {

        switch scheduled
            .timingStatus {

        case .noPreference:

            EmptyView()


        case .fitsPreference:

            Label(
                "\(timing) • fits",
                systemImage:
                    "checkmark.circle.fill"
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )


        case .waitedForPreference:

            Label(
                "\(timing) • planned for \(formatClock(scheduled.startTime))",
                systemImage:
                    "clock.badge.checkmark"
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )


        case .outsidePreference:

            Label(
                "\(timing) requested • \(formatClock(scheduled.startTime))",
                systemImage:
                    "exclamationmark.triangle"
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                .secondary
            )
        }
    }


    // MARK: - Route Connector

    @ViewBuilder
    private func routeConnector(
        to place:
            PlannedPlace
    ) -> some View {

        if let leg =
            routeLeg(
                to:
                    place
            ) {

            connector(
                leg:
                    leg
            )

        } else {

            routeUnavailableConnector
        }
    }


    private func connector(
        leg:
            RouteLeg
    ) -> some View {

        HStack(
            spacing:
                14
        ) {

            VStack(
                spacing:
                    0
            ) {

                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(
                                0.25
                            )
                    )
                    .frame(
                        width:
                            2,
                        height:
                            13
                    )


                Image(
                    systemName:
                        travelMode.icon
                )
                .font(
                    .system(
                        size:
                            11
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .padding(
                    .vertical,
                    5
                )


                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(
                                0.25
                            )
                    )
                    .frame(
                        width:
                            2,
                        height:
                            13
                    )
            }
            .frame(
                width:
                    42
            )


            Text(
                "\(formatTime(leg.travelTime))  •  \(formatDistance(leg.distance))"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Spacer()
        }
    }


    private var routeUnavailableConnector:
        some View {

        HStack(
            spacing:
                14
        ) {

            VStack(
                spacing:
                    0
            ) {

                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(
                                0.18
                            )
                    )
                    .frame(
                        width:
                            2,
                        height:
                            12
                    )


                Image(
                    systemName:
                        "ellipsis"
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .tertiary
                )
                .padding(
                    .vertical,
                    4
                )


                Rectangle()
                    .fill(
                        Color.secondary
                            .opacity(
                                0.18
                            )
                    )
                    .frame(
                        width:
                            2,
                        height:
                            12
                    )
            }
            .frame(
                width:
                    42
            )


            Text(
                "Route details unavailable"
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .tertiary
            )


            Spacer()
        }
    }


    // MARK: - Bottom

    private var bottomActions:
        some View {

        VStack(
            spacing:
                10
        ) {

            Button {
                isSavePromptPresented = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: didSave ? "checkmark.circle.fill" : "bookmark.fill")
                    Text(didSave ? "Saved" : "Save My Day")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(didSave)

            Button {

                dismiss()

            } label: {

                HStack {

                    Spacer()

                    Image(
                        systemName:
                            "map.fill"
                    )

                    Text(
                        "View on Map"
                    )
                    .font(
                        .headline
                    )

                    Spacer()
                }
                .padding(
                    .vertical,
                    14
                )
            }
            .buttonStyle(
                .borderedProminent
            )


            Button {

                dismiss()


                DispatchQueue.main
                    .asyncAfter(
                        deadline:
                            .now()
                            +
                            0.25
                    ) {

                        onEdit()
                    }

            } label: {

                HStack {

                    Spacer()

                    Image(
                        systemName:
                            "pencil"
                    )

                    Text(
                        "Edit Plan"
                    )
                    .font(
                        .headline
                    )

                    Spacer()
                }
                .padding(
                    .vertical,
                    14
                )
            }
            .buttonStyle(
                .bordered
            )
        }
    }

    private var defaultSavedTitle: String {
        let weekday = Date().formatted(.dateTime.weekday(.wide))
        return "\(weekday) Day"
    }

    private func saveDay(title: String) {
        let stops = itinerary.orderedPlaces.map { place in
            let scheduled = scheduledStop(for: place)
            return SavedStopRecord(
                id: place.id,
                name: place.name,
                address: place.mapItem.alongAddressText,
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude,
                startTime: scheduled?.startTime,
                endTime: scheduled?.departureTime
            )
        }

        modelContext.insert(
            SavedDay(
                title: title,
                plannedStart: itinerary.scheduledStops.first?.startTime,
                plannedEnd: itinerary.estimatedFinishTime,
                stops: stops
            )
        )

        try? modelContext.save()
        didSave = true
    }


    // MARK: - Lookups

    private func resolvedStop(
        for place:
            PlannedPlace
    ) -> ResolvedFlexibleStop? {

        itinerary
            .resolvedFlexibleStops
            .first {

                $0.place.id ==
                    place.id
            }
    }


    private func scheduledStop(
        for place:
            PlannedPlace
    ) -> ScheduledStop? {

        itinerary
            .scheduledStops
            .first {

                $0.place.id ==
                    place.id
            }
    }


    private func routeLeg(
        to place:
            PlannedPlace
    ) -> RouteLeg? {

        routeLegs.first {

            $0.toPlaceID ==
                place.id
        }
    }


    // MARK: - Formatting

    private func formatClock(
        _ date:
            Date
    ) -> String {

        date.formatted(
            date:
                .omitted,
            time:
                .shortened
        )
    }


    private func formatTime(
        _ seconds:
            TimeInterval
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
        _ meters:
            CLLocationDistance
    ) -> String {

        if meters < 1000 {

            return "\(Int(meters.rounded())) m"
        }


        return String(
            format:
                "%.1f km",
            meters / 1000
        )
    }
}
