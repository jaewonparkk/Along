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


    // MARK: - Travel Mode

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
                followsHeading: false,
                fallback: .automatic
            )


    // MARK: - Computed Places

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


            // MARK: Real MapKit Route

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


            // MARK: Numbered Stops

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
        number: Int
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

                spacing: 2
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


            if planningEngine.isPlanning {

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


    // MARK: - Plan Panel

    private var planPanel:
        some View {

        VStack(
            alignment:
                .leading,

            spacing: 14
        ) {

            panelHeader


            if planningEngine.isPlanning {

                planningProgress
            }


            if displayedPlaces.count >= 2 {

                travelPicker
            }


            if !displayedPlaces.isEmpty {

                itineraryOrder
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


                routeSummary
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

    private var panelHeader:
        some View {

        HStack {

            VStack(
                alignment:
                    .leading,

                spacing: 3
            ) {

                Text("Your day")
                    .font(
                        .headline
                    )


                Text(
                    "\(plan.anchors.count) fixed • \(plan.flexibleStops.count) flexible • \(plan.intent.optimizationGoal.title)"
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            if !displayedPlaces.isEmpty {

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


    // MARK: - Progress

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
                cornerRadius: 12
            )
        )
    }


    // MARK: - Travel

    private var travelPicker:
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


    // MARK: - Final Order

    private var itineraryOrder:
        some View {

        VStack(
            alignment:
                .leading,

            spacing: 8
        ) {

            HStack {

                Text(
                    planningEngine
                        .generatedItinerary
                    !=
                    nil
                    ?
                    "Optimized order"
                    :
                    "Stops"
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )


                Spacer()


                if planningEngine
                    .generatedItinerary
                    !=
                    nil {

                    Text(
                        "AUTO"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
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
                        Array(
                            displayedPlaces
                                .enumerated()
                        ),

                        id:
                            \.element.id
                    ) {
                        index,
                        place in


                        HStack(
                            spacing: 7
                        ) {

                            ZStack {

                                Circle()
                                    .fill(
                                        Color.accentColor
                                    )
                                    .frame(
                                        width: 24,
                                        height: 24
                                    )


                                Text(
                                    "\(index + 1)"
                                )
                                .font(
                                    .system(
                                        size: 10,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(
                                    .white
                                )
                            }


                            Text(
                                place.name
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


    // MARK: - Flexible Results

    private func resolvedFlexibleSection(
        _ itinerary:
            GeneratedItinerary
    ) -> some View {

        VStack(
            alignment:
                .leading,

            spacing: 9
        ) {

            Text(
                "Halfway picked"
            )
            .font(
                .caption
                    .weight(
                        .semibold
                    )
            )


            ForEach(
                itinerary
                    .resolvedFlexibleStops
            ) {
                resolved in


                HStack(
                    spacing: 9
                ) {

                    Image(
                        systemName:
                            resolved
                                .source
                                .category
                                .icon
                    )


                    VStack(
                        alignment:
                            .leading,

                        spacing: 2
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


    // MARK: - Route

    private var routeSummary:
        some View {

        VStack(
            alignment:
                .leading,

            spacing: 8
        ) {

            HStack {

                Text("Route")
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
                            travelMode.icon
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


    // MARK: - BUILD

    private func buildCurrentPlan() {

        directionsService
            .clear()


        /*
         ALL plans go through PlanningEngine.

         Even if there are only anchors.

         This is what enables automatic
         anchor ordering.
         */

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


            DispatchQueue.main
                .asyncAfter(
                    deadline:
                        .now()
                        +
                        0.3
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
            let minLat =
                latitudes.min(),

            let maxLat =
                latitudes.max(),

            let minLon =
                longitudes.min(),

            let maxLon =
                longitudes.max()

        else {

            return
        }


        let center =
            CLLocationCoordinate2D(
                latitude:
                    (
                        minLat
                        +
                        maxLat
                    ) / 2,

                longitude:
                    (
                        minLon
                        +
                        maxLon
                    ) / 2
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
                                    max(
                                        0.02,

                                        (
                                            maxLat
                                            -
                                            minLat
                                        )
                                        *
                                        1.6
                                    ),

                                longitudeDelta:
                                    max(
                                        0.02,

                                        (
                                            maxLon
                                            -
                                            minLon
                                        )
                                        *
                                        1.6
                                    )
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
