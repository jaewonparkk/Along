import SwiftUI
import MapKit
import CoreLocation


struct ContentView: View {

    // MARK: - Services

    @StateObject
    private var locationManager =
        LocationManager()


    @StateObject
    private var searchService =
        PlaceSearchService()


    @StateObject
    private var directionsService =
        DirectionsService()


    @StateObject
    private var planningEngine =
        PlanningEngine()


    // MARK: - Plan

    @State
    private var plan =
        PlanRequest()


    // MARK: - Travel

    @State
    private var travelMode:
        TravelMode = .walking


    // MARK: - UI

    @State
    private var isPlannerPresented =
        false


    // MARK: - Map

    @State
    private var cameraPosition:
        MapCameraPosition =
            .userLocation(
                followsHeading:
                    false,

                fallback:
                    .automatic
            )


    // MARK: - Places

    private var anchorPlaces:
        [PlannedPlace] {

        plan.anchorPlaces
    }


    private var displayedPlaces:
        [PlannedPlace] {

        if let generated =
            planningEngine
                .generatedItinerary {

            return generated
                .orderedPlaces
        }


        return anchorPlaces
    }


    // MARK: - Body

    var body: some View {

        ZStack {

            mapView

            overlayInterface
        }
        .sheet(
            isPresented:
                $isPlannerPresented
        ) {

            PlanSetupView(
                plan:
                    $plan,

                searchService:
                    searchService,

                userLocation:
                    locationManager
                        .lastLocation
            ) {

                buildCurrentPlan()
            }
        }
        .task {

            locationManager
                .requestPermission()
        }
        .onChange(
            of:
                travelMode
        ) {
            _,
            _ in


            guard
                !plan.anchors.isEmpty
                ||
                !plan.flexibleStops.isEmpty
            else {

                return
            }


            buildCurrentPlan()
        }
        .alert(
            "Couldn't build this plan",
            isPresented:
                Binding(
                    get: {

                        planningEngine
                            .errorMessage
                        !=
                        nil
                    },

                    set: {
                        visible in

                        if !visible {

                            planningEngine
                                .dismissError()
                        }
                    }
                )
        ) {

            Button("OK") {

                planningEngine
                    .dismissError()
            }

        } message: {

            Text(
                planningEngine
                    .errorMessage
                ??
                ""
            )
        }
    }


    // MARK: - Map

    private var mapView:
        some View {

        Map(
            position:
                $cameraPosition
        ) {

            UserAnnotation()


            // MARK: Actual MKDirections Routes

            ForEach(
                directionsService
                    .routeLegs
            ) {
                leg in


                MapPolyline(
                    leg.route
                )
                .stroke(
                    Color.accentColor,
                    lineWidth: 5
                )
            }


            // MARK: Final Itinerary Pins

            ForEach(
                Array(
                    displayedPlaces
                        .enumerated()
                ),

                id:
                    \.element.id
            ) {
                index,
                place in


                Annotation(
                    place.name,

                    coordinate:
                        place.coordinate
                ) {

                    mapPin(
                        number:
                            index + 1
                    )
                }
            }
        }
        .mapStyle(
            .standard(
                elevation:
                    .realistic
            )
        )
        .mapControls {

            MapUserLocationButton()

            MapCompass()

            MapScaleView()
        }
        .onMapCameraChange(
            frequency:
                .onEnd
        ) {
            context in


            searchService
                .updateRegion(
                    context.region
                )
        }
        .ignoresSafeArea()
    }


    // MARK: - Pin

    private func mapPin(
        number:
            Int
    ) -> some View {

        ZStack {

            Circle()
                .fill(
                    Color.accentColor
                )
                .frame(
                    width: 36,
                    height: 36
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
            .foregroundStyle(
                .white
            )
        }
        .overlay {

            Circle()
                .stroke(
                    .white,
                    lineWidth: 3
                )
        }
        .shadow(
            radius: 3
        )
    }


    // MARK: - Overlay

    private var overlayInterface:
        some View {

        VStack(
            spacing: 0
        ) {

            topBar


            Spacer()


            if
                !plan.anchors.isEmpty
                ||
                !plan.flexibleStops.isEmpty {

                planPanel
            }
        }
    }


    // MARK: - Top Bar

    private var topBar:
        some View {

        HStack(
            spacing: 12
        ) {

            VStack(
                alignment:
                    .leading,

                spacing:
                    2
            ) {

                Text("Halfway")
                    .font(
                        .system(
                            size: 26,
                            weight: .bold,
                            design: .rounded
                        )
                    )


                Text(
                    planningEngine.isPlanning
                    ?
                    "Building your day..."
                    :
                    "Tell us what you want to do."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if planningEngine
                .isPlanning {

                ProgressView()
                    .controlSize(
                        .small
                    )
            }


            Button {

                isPlannerPresented =
                    true

            } label: {

                HStack(
                    spacing: 7
                ) {

                    Image(
                        systemName:
                            "slider.horizontal.3"
                    )


                    Text("Plan")
                        .font(
                            .subheadline
                                .weight(
                                    .semibold
                                )
                        )
                }
                .padding(
                    .horizontal,
                    14
                )
                .frame(
                    height: 42
                )
                .background(
                    .regularMaterial
                )
                .clipShape(
                    Capsule()
                )
            }
            .buttonStyle(
                .plain
            )
        }
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
        .background(
            .ultraThinMaterial
        )
    }


    // MARK: - Panel

    private var planPanel:
        some View {

        VStack(
            alignment:
                .leading,

            spacing:
                14
        ) {

            planPanelHeader


            if planningEngine
                .isPlanning {

                planningProgress
            }


            if displayedPlaces.count >= 2 {

                travelModePicker
            }


            if !plan
                .anchors
                .isEmpty {

                anchorSection
            }


            if !plan
                .flexibleStops
                .isEmpty {

                flexibleRequestSection
            }


            if let itinerary =
                planningEngine
                    .generatedItinerary,
               !itinerary
                    .resolvedFlexibleStops
                    .isEmpty {

                Divider()


                resolvedFlexibleSection(
                    itinerary
                )
            }


            if !directionsService
                .routeLegs
                .isEmpty {

                Divider()


                routeSummarySection
            }
        }
        .padding(18)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .padding(
            .horizontal,
            12
        )
        .padding(
            .bottom,
            12
        )
    }


    // MARK: - Header

    private var planPanelHeader:
        some View {

        HStack {

            VStack(
                alignment:
                    .leading,

                spacing:
                    3
            ) {

                Text("Your day")
                    .font(
                        .headline
                    )


                Text(
                    planSummaryText
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if !displayedPlaces
                .isEmpty {

                Button {

                    zoomToDisplayedPlaces()

                } label: {

                    Image(
                        systemName:
                            "arrow.up.left.and.arrow.down.right"
                    )
                }
                .buttonStyle(
                    .plain
                )
            }


            Button {

                isPlannerPresented =
                    true

            } label: {

                Image(
                    systemName:
                        "pencil"
                )
            }
            .buttonStyle(
                .plain
            )
        }
    }


    private var planSummaryText:
        String {

        "\(plan.anchors.count) fixed • \(plan.flexibleStops.count) flexible • \(plan.intent.optimizationGoal.title)"
    }


    // MARK: - Planning Progress

    private var planningProgress:
        some View {

        HStack(
            spacing: 10
        ) {

            ProgressView()
                .controlSize(
                    .small
                )


            Text(
                planningEngine
                    .progressMessage
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Spacer()
        }
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            10
        )
        .background(
            Color.primary
                .opacity(
                    0.05
                )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }


    // MARK: - Travel Mode

    private var travelModePicker:
        some View {

        Picker(
            "Travel mode",

            selection:
                $travelMode
        ) {

            ForEach(
                TravelMode.allCases
            ) {
                mode in


                Label(
                    mode.title,

                    systemImage:
                        mode.icon
                )
                .tag(
                    mode
                )
            }
        }
        .pickerStyle(
            .segmented
        )
        .disabled(
            planningEngine
                .isPlanning
        )
    }


    // MARK: - Anchors

    private var anchorSection:
        some View {

        VStack(
            alignment:
                .leading,

            spacing:
                8
        ) {

            Text(
                "Must visit"
            )
            .font(
                .caption
                    .weight(
                        .semibold
                    )
            )


            ScrollView(
                .horizontal,

                showsIndicators:
                    false
            ) {

                HStack(
                    spacing: 8
                ) {

                    ForEach(
                        plan.anchors
                    ) {
                        anchor in


                        HStack(
                            spacing: 6
                        ) {

                            Image(
                                systemName:
                                    "heart.fill"
                            )
                            .font(
                                .caption
                            )


                            Text(
                                anchor
                                    .place
                                    .name
                            )
                            .font(
                                .caption
                                    .weight(
                                        .medium
                                    )
                            )
                            .lineLimit(1)
                        }
                        .padding(
                            .horizontal,
                            10
                        )
                        .padding(
                            .vertical,
                            7
                        )
                        .background(
                            Color.primary
                                .opacity(
                                    0.06
                                )
                        )
                        .clipShape(
                            Capsule()
                        )
                    }
                }
            }
        }
    }


    // MARK: - Flexible Requests

    private var flexibleRequestSection:
        some View {

        VStack(
            alignment:
                .leading,

            spacing:
                8
        ) {

            HStack {

                Text(
                    "Requested"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )


                Spacer()


                Text(
                    plan.intent
                        .startPreference
                        .title
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            ScrollView(
                .horizontal,

                showsIndicators:
                    false
            ) {

                HStack(
                    spacing: 8
                ) {

                    ForEach(
                        plan.flexibleStops
                    ) {
                        stop in


                        flexibleRequestChip(
                            stop
                        )
                    }
                }
            }
        }
    }


    private func flexibleRequestChip(
        _ stop:
            FlexibleStop
    ) -> some View {

        HStack(
            spacing: 6
        ) {

            Image(
                systemName:
                    stop
                        .category
                        .icon
            )


            VStack(
                alignment:
                    .leading,

                spacing:
                    1
            ) {

                Text(
                    stop
                        .category
                        .title
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )


                let detail =
                    stop.query
                        .trimmingCharacters(
                            in:
                                CharacterSet
                                    .whitespacesAndNewlines
                        )


                if !detail.isEmpty {

                    Text(
                        detail
                    )
                    .font(
                        .system(
                            size: 10
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
                }
            }
        }
        .padding(
            .horizontal,
            10
        )
        .padding(
            .vertical,
            7
        )
        .background(
            Color.primary
                .opacity(
                    0.06
                )
        )
        .clipShape(
            Capsule()
        )
    }


    // MARK: - Resolved Stops

    private func resolvedFlexibleSection(
        _ itinerary:
            GeneratedItinerary
    ) -> some View {

        VStack(
            alignment:
                .leading,

            spacing:
                10
        ) {

            HStack {

                Image(
                    systemName:
                        "wand.and.stars"
                )


                Text(
                    "Halfway picked"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )
            }


            ForEach(
                itinerary
                    .resolvedFlexibleStops
            ) {
                resolved in


                HStack(
                    spacing: 10
                ) {

                    Image(
                        systemName:
                            resolved
                                .source
                                .category
                                .icon
                    )
                    .frame(
                        width: 20
                    )


                    VStack(
                        alignment:
                            .leading,

                        spacing:
                            2
                    ) {

                        Text(
                            resolved
                                .place
                                .name
                        )
                        .font(
                            .caption
                                .weight(
                                    .semibold
                                )
                        )


                        Text(
                            resolved
                                .source
                                .category
                                .title
                        )
                        .font(
                            .system(
                                size: 10
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    Spacer()


                    Text(
                        "+\(formatTime(resolved.addedTravelTime))"
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
    }


    // MARK: - Route Summary

    private var routeSummarySection:
        some View {

        VStack(
            alignment:
                .leading,

            spacing:
                8
        ) {

            HStack {

                Text(
                    "Route"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )


                Spacer()


                Text(
                    "\(formatTime(directionsService.totalTravelTime)) • \(formatDistance(directionsService.totalDistance))"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            ForEach(
                directionsService
                    .routeLegs
            ) {
                leg in


                HStack(
                    spacing: 7
                ) {

                    Image(
                        systemName:
                            travelMode
                                .icon
                    )
                    .font(
                        .caption
                    )


                    Text(
                        leg.from.name
                    )
                    .lineLimit(1)


                    Image(
                        systemName:
                            "arrow.right"
                    )
                    .font(
                        .system(
                            size: 8
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )


                    Text(
                        leg.to.name
                    )
                    .lineLimit(1)


                    Spacer()


                    Text(
                        formatTime(
                            leg.travelTime
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .font(
                    .caption
                )
            }
        }
    }


    // MARK: - Build Plan

    private func buildCurrentPlan() {

        directionsService
            .clear()


        // MARK: Anchors Only

        if plan.flexibleStops
            .isEmpty {

            planningEngine
                .clearGeneratedPlan()


            directionsService
                .buildRoute(
                    for:
                        anchorPlaces,

                    travelMode:
                        travelMode
                )


            DispatchQueue
                .main
                .asyncAfter(
                    deadline:
                        .now()
                        +
                        0.25
                ) {

                    zoomToDisplayedPlaces()
                }


            return
        }


        // MARK: Full Planning Engine

        planningEngine.build(
            plan:
                plan,

            userLocation:
                locationManager
                    .lastLocation,

            travelMode:
                travelMode
        ) {
            itinerary in


            guard let itinerary else {

                return
            }


            directionsService
                .buildRoute(
                    for:
                        itinerary
                            .orderedPlaces,

                    travelMode:
                        travelMode
                )


            DispatchQueue
                .main
                .asyncAfter(
                    deadline:
                        .now()
                        +
                        0.35
                ) {

                    zoomToDisplayedPlaces()
                }
        }
    }


    // MARK: - Zoom

    private func zoomToDisplayedPlaces() {

        let places =
            displayedPlaces


        guard !places.isEmpty else {

            return
        }


        if places.count == 1 {

            withAnimation {

                cameraPosition =
                    .region(
                        MKCoordinateRegion(
                            center:
                                places[0]
                                    .coordinate,

                            span:
                                MKCoordinateSpan(
                                    latitudeDelta:
                                        0.02,

                                    longitudeDelta:
                                        0.02
                                )
                        )
                    )
            }


            return
        }


        let latitudes =
            places.map {
                $0.coordinate.latitude
            }


        let longitudes =
            places.map {
                $0.coordinate.longitude
            }


        guard
            let minLatitude =
                latitudes.min(),

            let maxLatitude =
                latitudes.max(),

            let minLongitude =
                longitudes.min(),

            let maxLongitude =
                longitudes.max()

        else {

            return
        }


        let center =
            CLLocationCoordinate2D(
                latitude:
                    (
                        minLatitude
                        +
                        maxLatitude
                    )
                    /
                    2,

                longitude:
                    (
                        minLongitude
                        +
                        maxLongitude
                    )
                    /
                    2
            )


        let latitudeDelta =
            max(
                0.02,

                (
                    maxLatitude
                    -
                    minLatitude
                )
                *
                1.6
            )


        let longitudeDelta =
            max(
                0.02,

                (
                    maxLongitude
                    -
                    minLongitude
                )
                *
                1.6
            )


        withAnimation {

            cameraPosition =
                .region(
                    MKCoordinateRegion(
                        center:
                            center,

                        span:
                            MKCoordinateSpan(
                                latitudeDelta:
                                    latitudeDelta,

                                longitudeDelta:
                                    longitudeDelta
                            )
                    )
                )
        }
    }


    // MARK: - Formatting

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
}


// MARK: - Preview

#Preview {
    ContentView()
}
