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


    // MARK: - Sheets

    @State
    private var isPlannerPresented =
        false


    @State
    private var isResultPresented =
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


    // MARK: - Error

    private var currentErrorMessage:
        String? {

        if let planningError =
            planningEngine
                .errorMessage {

            return planningError
        }


        return directionsService
            .errorMessage
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

                buildCurrentPlan(
                    showResult:
                        true
                )
            }
        }
        .sheet(
            isPresented:
                $isResultPresented
        ) {

            if let itinerary =
                planningEngine
                    .generatedItinerary {

                ItineraryResultView(
                    itinerary:
                        itinerary,

                    routeLegs:
                        directionsService
                            .routeLegs,

                    totalTravelTime:
                        directionsService
                            .totalTravelTime,

                    totalDistance:
                        directionsService
                            .totalDistance,

                    travelMode:
                        travelMode,

                    hasCurrentLocation:
                        locationManager
                            .lastLocation
                        !=
                        nil
                ) {

                    isPlannerPresented =
                        true
                }
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


            /*
             Rebuild because route optimization
             can change based on walking,
             driving, or transit.

             Don't automatically pop open
             result sheet here.
             */

            buildCurrentPlan(
                showResult:
                    false
            )
        }
        .alert(
            "Couldn't complete the route",

            isPresented:
                Binding(
                    get: {

                        currentErrorMessage
                        !=
                        nil
                    },

                    set: {
                        visible in


                        if !visible {

                            planningEngine
                                .dismissError()


                            directionsService
                                .dismissError()
                        }
                    }
                )
        ) {

            Button("OK") {

                planningEngine
                    .dismissError()


                directionsService
                    .dismissError()
            }

        } message: {

            Text(
                currentErrorMessage
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

            // MARK: User Location

            UserAnnotation()


            // MARK: Actual MKRoute Polylines

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


            // MARK: Stop Pins

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


    // MARK: - Map Pin

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
            .foregroundStyle(.white)
        }
        .overlay {

            Circle()
                .stroke(
                    .white,
                    lineWidth: 3
                )
        }
        .shadow(radius: 3)
    }


    // MARK: - Overlay

    private var overlayInterface:
        some View {

        VStack(spacing: 0) {

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

        HStack(spacing: 12) {

            VStack(
                alignment: .leading,
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


                if planningEngine.isPlanning {

                    Text(
                        planningEngine
                            .progressMessage
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } else if directionsService.isLoading {

                    Text("Drawing your route...")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                } else {

                    Text(
                        "Tell us what you want to do."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }


            Spacer()


            if planningEngine.isPlanning
                ||
                directionsService.isLoading {

                ProgressView()
                    .controlSize(.small)
            }


            Button {

                isPlannerPresented =
                    true

            } label: {

                HStack(spacing: 7) {

                    Image(
                        systemName:
                            "slider.horizontal.3"
                    )


                    Text("Plan")
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )
                }
                .padding(
                    .horizontal,
                    14
                )
                .frame(height: 42)
                .background(
                    .regularMaterial
                )
                .clipShape(
                    Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            .ultraThinMaterial
        )
    }


    // MARK: - Plan Panel

    private var planPanel:
        some View {

        VStack(
            alignment: .leading,
            spacing: 13
        ) {

            panelHeader


            if displayedPlaces.count >= 1 {

                travelPicker
            }


            if !displayedPlaces.isEmpty {

                itineraryOrder
            }


            if !directionsService
                .routeLegs
                .isEmpty {

                Divider()


                routeSummary
            }


            if let itinerary =
                planningEngine
                    .generatedItinerary,
               !itinerary
                    .orderedPlaces
                    .isEmpty {

                Button {

                    isResultPresented =
                        true

                } label: {

                    HStack {

                        Spacer()


                        Image(
                            systemName:
                                "list.bullet.rectangle"
                        )


                        Text(
                            "View Full Itinerary"
                        )
                        .font(
                            .subheadline
                                .weight(.semibold)
                        )


                        Spacer()
                    }
                    .padding(
                        .vertical,
                        10
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
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
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }


    // MARK: - Panel Header

    private var panelHeader:
        some View {

        HStack {

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text("Your day")
                    .font(.headline)


                Text(
                    "\(plan.anchors.count) fixed • \(plan.flexibleStops.count) flexible • \(plan.intent.optimizationGoal.title)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }


            Spacer()


            if !displayedPlaces.isEmpty {

                Button {

                    zoomToRoute()

                } label: {

                    Image(
                        systemName:
                            "arrow.up.left.and.arrow.down.right"
                    )
                }
                .buttonStyle(.plain)
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
            .buttonStyle(.plain)
        }
    }


    // MARK: - Travel Picker

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
                .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .disabled(
            planningEngine.isPlanning
            ||
            directionsService.isLoading
        )
    }


    // MARK: - Itinerary Order

    private var itineraryOrder:
        some View {

        VStack(
            alignment: .leading,
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
                        .weight(.semibold)
                )


                Spacer()


                if planningEngine
                    .generatedItinerary
                    !=
                    nil {

                    Text("AUTO")
                        .font(
                            .system(
                                size: 9,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.secondary)
                }
            }


            ScrollView(
                .horizontal,
                showsIndicators: false
            ) {

                HStack(spacing: 8) {

                    ForEach(
                        Array(
                            displayedPlaces
                                .enumerated()
                        ),
                        id: \.element.id
                    ) {
                        index,
                        place in


                        stopChip(
                            place:
                                place,

                            number:
                                index + 1
                        )
                    }
                }
            }
        }
    }


    // MARK: - Stop Chip

    private func stopChip(
        place: PlannedPlace,
        number: Int
    ) -> some View {

        HStack(spacing: 7) {

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
                    "\(number)"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)
            }


            Text(place.name)
                .font(
                    .caption
                        .weight(.medium)
                )
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Color.primary.opacity(0.06)
        )
        .clipShape(
            Capsule()
        )
    }


    // MARK: - Route Summary

    private var routeSummary:
        some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack {

                Text("Route")
                    .font(
                        .caption
                            .weight(.semibold)
                    )


                Spacer()


                Text(
                    "\(formatTime(directionsService.totalTravelTime)) • \(formatDistance(directionsService.totalDistance))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }


            ForEach(
                directionsService
                    .routeLegs
            ) {
                leg in


                HStack(spacing: 7) {

                    Image(
                        systemName:
                            travelMode.icon
                    )
                    .font(.caption)


                    Text(
                        leg.fromName
                    )
                    .lineLimit(1)


                    Image(
                        systemName:
                            "arrow.right"
                    )
                    .font(
                        .system(size: 8)
                    )
                    .foregroundStyle(.secondary)


                    Text(
                        leg.toName
                    )
                    .lineLimit(1)


                    Spacer()


                    Text(
                        formatTime(
                            leg.travelTime
                        )
                    )
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }


    // MARK: - Build

    private func buildCurrentPlan(
        showResult: Bool
    ) {

        directionsService.clear()


        planningEngine.build(
            plan: plan,

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


            directionsService.buildRoute(
                for:
                    itinerary
                        .orderedPlaces,

                from:
                    locationManager
                        .lastLocation,

                travelMode:
                    travelMode
            ) {
                success in


                zoomToRoute()


                /*
                 Show the result screen only
                 when the user explicitly tapped
                 Build My Day.
                 */

                guard showResult else {
                    return
                }


                /*
                 Even if one final route leg
                 fails, DirectionsService will
                 already show a useful error.

                 Don't stack two modals.
                 */

                guard success else {
                    return
                }


                DispatchQueue.main
                    .asyncAfter(
                        deadline:
                            .now()
                            +
                            0.35
                    ) {

                        isResultPresented =
                            true
                    }
            }
        }
    }


    // MARK: - Zoom

    private func zoomToRoute() {

        var coordinates =
            displayedPlaces.map {
                $0.coordinate
            }


        /*
         Include current location so the
         first route segment also fits
         inside the camera.
         */

        if let userLocation =
            locationManager
                .lastLocation {

            coordinates.insert(
                userLocation.coordinate,
                at: 0
            )
        }


        guard !coordinates.isEmpty else {
            return
        }


        // MARK: Single Coordinate

        if coordinates.count == 1 {

            withAnimation {

                cameraPosition =
                    .region(
                        MKCoordinateRegion(
                            center:
                                coordinates[0],

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
            coordinates.map {
                $0.latitude
            }


        let longitudes =
            coordinates.map {
                $0.longitude
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
}


// MARK: - Preview

#Preview {

    ContentView()
}
