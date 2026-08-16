import SwiftUI
import MapKit
import CoreLocation


struct PlanSetupView: View {

    @Binding
    var plan: PlanRequest


    @ObservedObject
    var searchService:
        PlaceSearchService


    let userLocation:
        CLLocation?


    let onBuild:
        () -> Void


    @Environment(\.dismiss)
    private var dismiss


    @State
    private var isAddingAnchor =
        false


    var body: some View {

        NavigationStack {

            Form {
                mustVisitSection
                flexibleStopsSection
                visitOrderSection
                todaysStyleSection
                planSummarySection
            }
            .navigationTitle(
                "Plan Your Day"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarLeading
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(
                edge:
                    .bottom
            ) {

                buildButton
            }
        }
        .sheet(
            isPresented:
                $isAddingAnchor
        ) {

            PlaceSearchView(
                searchService:
                    searchService,

                referencePlace:
                    plan
                        .anchors
                        .last?
                        .place,

                userLocation:
                    userLocation
            ) {
                mapItem in


                addAnchor(
                    mapItem
                )
            }
        }
    }


    // MARK: - Must Visit

    private var mustVisitSection:
        some View {

        Section {

            if plan.anchors.isEmpty {

                Text(
                    "Add somewhere you definitely want to visit."
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    Array(plan.anchors.enumerated()),
                    id: \.element.id
                ) { index, anchor in
                    anchorRow(anchor, index: index)
                }
            }


            Button {

                isAddingAnchor =
                    true

            } label: {

                Label(
                    "Add a place",
                    systemImage:
                        "plus.circle.fill"
                )
            }

        } header: {

            Label(
                "Must Visit",
                systemImage:
                    "heart.fill"
            )
        }
    }


    // MARK: - Flexible Stops

    private var flexibleStopsSection:
        some View {

        Section {

            ForEach(
                $plan.flexibleStops
            ) {
                $stop in


                flexibleStopEditor(
                    stop:
                        $stop
                )
            }


            addFlexibleStopMenu

        } header: {

            Label(
                "I Also Want To...",
                systemImage:
                    "sparkles"
            )

        } footer: {

            Text(
                "Along uses what you type, timing, opening hours, and travel time to choose the actual place."
            )
        }
    }


    // MARK: - Flexible Editor

    private func flexibleStopEditor(
        stop:
            Binding<FlexibleStop>
    ) -> some View {

        VStack(
            alignment:
                .leading,
            spacing:
                13
        ) {

            HStack(
                spacing:
                    10
            ) {

                Image(
                    systemName:
                        stop
                            .wrappedValue
                            .category
                            .icon
                )
                .frame(
                    width:
                        25
                )


                Picker(
                    "Type",
                    selection:
                        stop.category
                ) {

                    ForEach(
                        FlexibleStopCategory
                            .allCases
                    ) {
                        category in


                        Text(
                            category.title
                        )
                        .tag(
                            category
                        )
                    }
                }
                .labelsHidden()


                Spacer()


                Button {

                    removeFlexibleStop(
                        id:
                            stop
                                .wrappedValue
                                .id
                    )

                } label: {

                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                .buttonStyle(
                    .plain
                )
            }


            TextField(
                stop
                    .wrappedValue
                    .category
                    .placeholder,

                text:
                    stop.query
            )


        }
        .padding(
            .vertical,
            7
        )
    }

    private var visitOrderSection: some View {
        Section {
            if totalRequestedStopCount == 0 {
                Text("Add a stop to set its order and stay time.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(plan.visitOrder.enumerated()), id: \.element.id) { index, reference in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                            .background(Color.accentColor, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(orderTitle(reference))
                            Menu {
                                ForEach(durationChoices, id: \.self) { duration in
                                    Button {
                                        setDuration(duration, for: reference)
                                    } label: {
                                        if duration == durationPreference(for: reference) {
                                            Label(duration.title, systemImage: "checkmark")
                                        } else {
                                            Text(duration.title)
                                        }
                                    }
                                }
                            } label: {
                                Label(
                                    durationPreference(for: reference).title,
                                    systemImage: "clock"
                                )
                                .font(.caption)
                            }
                        }
                        Spacer()
                        Button { moveOrder(from: index, by: -1) } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(index == 0)
                        .buttonStyle(.borderless)
                        Button { moveOrder(from: index, by: 1) } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(index == plan.visitOrder.count - 1)
                        .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Label("Visit Order", systemImage: "arrow.up.arrow.down")
        } footer: {
            Text(totalRequestedStopCount == 1
                 ? "Choose how long you want to stay. Add another stop to arrange the order."
                 : "Choose the order and how long to stay at each stop.")
        }
        .onAppear { plan.syncVisitOrder() }
    }


    // MARK: - Add Flexible

    private var addFlexibleStopMenu:
        some View {

        Menu {

            ForEach(
                FlexibleStopCategory
                    .allCases
            ) {
                category in


                Button {

                    addFlexibleStop(
                        category
                    )

                } label: {

                    Label(
                        category.title,
                        systemImage:
                            category.icon
                    )
                }
            }

        } label: {

            Label(
                "Add something",
                systemImage:
                    "plus.circle.fill"
            )
        }
    }


    // MARK: - Today's Style

    private var todaysStyleSection:
        some View {

        Section {

            DatePicker(
                "Day starts",
                selection:
                    $plan
                        .intent
                        .dayStart,
                displayedComponents:
                    .hourAndMinute
            )


            DatePicker(
                "Finish by",
                selection:
                    $plan
                        .intent
                        .finishBy,
                displayedComponents:
                    .hourAndMinute
            )


            Picker(
                "Pace",
                selection:
                    $plan
                        .intent
                        .pace
            ) {

                ForEach(
                    DayPace.allCases
                ) {
                    pace in


                    Text(
                        pace.title
                    )
                    .tag(
                        pace
                    )
                }
            }


            Text(
                plan
                    .intent
                    .pace
                    .subtitle
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )


            Picker(
                "Optimize for",
                selection:
                    $plan
                        .intent
                        .optimizationGoal
            ) {

                ForEach(
                    OptimizationGoal
                        .allCases
                ) {
                    goal in


                    Text(
                        goal.title
                    )
                    .tag(
                        goal
                    )
                }
            }


            Text(
                plan
                    .intent
                    .optimizationGoal
                    .subtitle
            )
            .font(
                .caption
            )
            .foregroundStyle(
                .secondary
            )

        } header: {

            Label(
                "Today's Style",
                systemImage:
                    "slider.horizontal.3"
            )
        }
    }


    // MARK: - Summary

    private var planSummarySection:
        some View {

        Section {

            HStack {

                Text(
                    "Must-visits"
                )


                Spacer()


                Text(
                    "\(plan.anchors.count)"
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack {

                Text(
                    "Flexible stops"
                )


                Spacer()


                Text(
                    "\(plan.flexibleStops.count)"
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack {

                Text(
                    "Day"
                )


                Spacer()


                Text(
                    dayWindowText
                )
                .foregroundStyle(
                    .secondary
                )
            }

        } header: {

            Text(
                "Plan Summary"
            )
        }
    }


    // MARK: - Build

    private var buildButton:
        some View {

        VStack {

            Divider()


            Button {
                onBuild()
                dismiss()

            } label: {

                HStack {

                    Spacer()


                    Image(
                        systemName:
                            "wand.and.stars"
                    )


                    Text(
                        "Build My Day"
                    )
                    .font(
                        .headline
                    )


                    Spacer()
                }
                .padding(
                    .vertical,
                    15
                )
            }
            .buttonStyle(
                .borderedProminent
            )
            .padding(
                .horizontal,
                16
            )
            .padding(
                .vertical,
                10
            )
            .disabled(
                totalRequestedStopCount
                ==
                0
            )
        }
        .background(
            .regularMaterial
        )
    }


    // MARK: - Anchor Row

    private func anchorRow(
        _ anchor:
            AnchorStop,
        index:
            Int
    ) -> some View {

        HStack {

            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 30, height: 30)

                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }


            VStack(
                alignment:
                    .leading
            ) {

                Text(
                    anchor.place.name
                )


                let address =
                    anchor
                        .place
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
                        .secondary
                    )
                    .lineLimit(
                        1
                    )
                }
            }


            Spacer()


            Button {

                removeAnchor(
                    anchor
                )

            } label: {

                Image(
                    systemName:
                        "xmark.circle.fill"
                )
                .foregroundStyle(
                    .secondary
                )
            }
            .buttonStyle(
                .plain
            )
        }
    }


    // MARK: - Actions

    private func addAnchor(
        _ mapItem:
            MKMapItem
    ) {

        let place =
            PlannedPlace(
                mapItem:
                    mapItem
            )


        plan.anchors.append(
            AnchorStop(
                place:
                    place
            )
        )

        plan.syncVisitOrder()


        searchService.clear()


        isAddingAnchor =
            false
    }


    private func removeAnchor(
        _ anchor:
            AnchorStop
    ) {

        plan.anchors.removeAll {

            $0.id ==
                anchor.id
        }

        plan.syncVisitOrder()


        if plan.anchors.isEmpty,
           plan.intent.startPreference
            ==
            .mustVisitsFirst {

            plan.intent.startPreference =
                .noPreference
        }
    }


    private func addFlexibleStop(
        _ category:
            FlexibleStopCategory
    ) {

        plan.flexibleStops.append(
            FlexibleStop(
                category:
                    category
            )
        )
        plan.syncVisitOrder()
    }


    private func removeFlexibleStop(
        id:
            UUID
    ) {

        if case
            .flexibleStop(
                let preferredID
            ) =
            plan
                .intent
                .startPreference,
           preferredID ==
            id {

            plan.intent.startPreference =
                .noPreference
        }


        plan.flexibleStops
            .removeAll {

                $0.id ==
                    id
            }

        plan.syncVisitOrder()
    }

    private func orderTitle(_ reference: PlanRequest.StopReference) -> String {
        switch reference {
        case .anchor(let id):
            return plan.anchors.first(where: { $0.place.id == id })?.place.name ?? "Place"
        case .flexible(let id):
            guard let stop = plan.flexibleStops.first(where: { $0.id == id }) else { return "Stop" }
            return flexiblePreferenceName(stop)
        }
    }

    private func moveOrder(from index: Int, by offset: Int) {
        let destination = index + offset
        guard plan.visitOrder.indices.contains(index), plan.visitOrder.indices.contains(destination) else { return }
        plan.visitOrder.swapAt(index, destination)
    }

    private var durationChoices: [StopDurationPreference] {
        [.unspecified, .thirtyMinutes, .oneHour, .ninetyMinutes, .twoHours,
         .threeHours, .fourHours, .fiveHours, .sixHours]
    }

    private func durationPreference(
        for reference: PlanRequest.StopReference
    ) -> StopDurationPreference {
        switch reference {
        case .anchor(let id):
            return plan.anchors.first(where: { $0.place.id == id })?.stayDuration ?? .unspecified
        case .flexible(let id):
            return plan.flexibleStops.first(where: { $0.id == id })?.stayDuration ?? .unspecified
        }
    }

    private func setDuration(
        _ duration: StopDurationPreference,
        for reference: PlanRequest.StopReference
    ) {
        switch reference {
        case .anchor(let id):
            guard let index = plan.anchors.firstIndex(where: { $0.place.id == id }) else { return }
            plan.anchors[index].stayDuration = duration
        case .flexible(let id):
            guard let index = plan.flexibleStops.firstIndex(where: { $0.id == id }) else { return }
            plan.flexibleStops[index].stayDuration = duration
        }
    }


    // MARK: - Dynamic Preference Text

    private var totalRequestedStopCount:
        Int {

        plan.anchors.count
        +
        plan.flexibleStops.count
    }


    private func flexiblePreferenceName(
        _ stop:
            FlexibleStop
    ) -> String {

        let query =
            stop.query
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )


        if query.isEmpty {

            return stop
                .category
                .title
        }


        return "\(stop.category.title) • \(query)"
    }


    private var startPreferenceDescription:
        String {

        switch plan
            .intent
            .startPreference {

        case .noPreference:

            return
                "Let Along choose the most sensible first stop."


        case .mustVisitsFirst:

            return
                "Visit your fixed places before flexible requests."


        case .flexibleStop(
            let id
        ):

            guard
                let stop =
                    plan.flexibleStops
                        .first(
                            where: {

                                $0.id ==
                                    id
                            }
                        )
            else {

                return
                    "Let Along choose the first stop."
            }


            return
                "Try to begin with \(flexiblePreferenceName(stop))."
        }
    }


    private var dayWindowText:
        String {

        let start =
            plan
                .intent
                .dayStart
                .formatted(
                    date:
                        .omitted,
                    time:
                        .shortened
                )


        let finish =
            plan
                .intent
                .finishBy
                .formatted(
                    date:
                        .omitted,
                    time:
                        .shortened
                )


        return "\(start) – \(finish)"
    }
}
