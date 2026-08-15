import SwiftUI
import MapKit
import CoreLocation


struct PlanSetupView: View {

    // MARK: - Data

    @Binding
    var plan: PlanRequest


    @ObservedObject
    var searchService:
        PlaceSearchService


    let userLocation:
        CLLocation?


    let onBuild:
        () -> Void


    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss


    // MARK: - UI

    @State
    private var isAddingAnchor =
        false


    // MARK: - Body

    var body: some View {

        NavigationStack {

            Form {

                mustVisitSection

                flexibleStopsSection

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
                edge: .bottom
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


    // MARK: - Must Visit Section

    private var mustVisitSection:
        some View {

        Section {

            if plan.anchors.isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(
                        "No fixed places yet"
                    )
                    .font(
                        .subheadline
                            .weight(.medium)
                    )


                    Text(
                        "Add anywhere you definitely want to visit."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    4
                )

            } else {

                ForEach(
                    Array(
                        plan
                            .anchors
                            .enumerated()
                    ),
                    id: \.element.id
                ) {
                    index,
                    anchor in

                    anchorRow(
                        anchor,
                        index:
                            index
                    )
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

        } footer: {

            Text(
                "Specific places that must be part of your day."
            )
        }
    }


    // MARK: - Flexible Stops Section

    private var flexibleStopsSection:
        some View {

        Section {

            if plan.flexibleStops
                .isEmpty {

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(
                        "What else do you want to do?"
                    )
                    .font(
                        .subheadline
                            .weight(.medium)
                    )


                    Text(
                        "Add things like matcha, lunch, wine, shopping, dessert, or an activity. Halfway will choose the actual place."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .padding(
                    .vertical,
                    4
                )

            } else {

                ForEach(
                    $plan.flexibleStops
                ) {
                    $stop in

                    flexibleStopEditor(
                        stop:
                            $stop
                    )
                }
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
                "Tell Halfway what you want and roughly when you want it. The actual place will be chosen from real map results."
            )
        }
    }


    // MARK: - Flexible Stop Editor

    private func flexibleStopEditor(
        stop:
            Binding<FlexibleStop>
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 13
        ) {

            // MARK: Category

            HStack(
                spacing: 10
            ) {

                Image(
                    systemName:
                        stop
                            .wrappedValue
                            .category
                            .icon
                )
                .frame(
                    width: 25
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


            // MARK: Natural Language Detail

            TextField(
                stop
                    .wrappedValue
                    .category
                    .placeholder,

                text:
                    stop.query
            )
            .textInputAutocapitalization(
                .sentences
            )


            Divider()


            // MARK: When

            Picker(
                "When",
                selection:
                    stop.timePreference
            ) {

                ForEach(
                    FlexibleStopTimePreference
                        .allCases
                ) {
                    preference in

                    Label(
                        preference.title,
                        systemImage:
                            preference.icon
                    )
                    .tag(
                        preference
                    )
                }
            }


            // MARK: Specific Time

            if stop
                .wrappedValue
                .timePreference
                ==
                .specific {

                DatePicker(
                    "Preferred time",
                    selection:
                        stop.specificTime,
                    displayedComponents:
                        .hourAndMinute
                )
                .datePickerStyle(
                    .compact
                )
            }


            // MARK: More Options

            DisclosureGroup {

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Picker(
                        "Stay",
                        selection:
                            stop.stayDuration
                    ) {

                        ForEach(
                            StopDurationPreference
                                .allCases
                        ) {
                            duration in

                            Text(
                                duration.title
                            )
                            .tag(
                                duration
                            )
                        }
                    }


                    if stop
                        .wrappedValue
                        .stayDuration
                        ==
                        .custom {

                        Stepper(
                            value:
                                stop
                                    .customStayMinutes,
                            in:
                                15...360,
                            step:
                                15
                        ) {

                            HStack {

                                Text(
                                    "Stay for"
                                )


                                Spacer()


                                Text(
                                    formatMinutes(
                                        stop
                                            .wrappedValue
                                            .customStayMinutes
                                    )
                                )
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                        }
                    }


                    Toggle(
                        "Must fit this into my day",
                        isOn:
                            stop.isRequired
                    )
                }
                .padding(
                    .top,
                    8
                )

            } label: {

                Label(
                    "More options",
                    systemImage:
                        "slider.horizontal.3"
                )
                .font(
                    .subheadline
                )
            }
        }
        .padding(
            .vertical,
            7
        )
    }


    // MARK: - Add Flexible Stop

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

            // MARK: Day Start

            DatePicker(
                "Day starts",
                selection:
                    $plan.intent.dayStart,
                displayedComponents:
                    .hourAndMinute
            )


            // MARK: Finish By

            DatePicker(
                "Finish by",
                selection:
                    $plan.intent.finishBy,
                displayedComponents:
                    .hourAndMinute
            )


            // MARK: Pace

            Picker(
                "Pace",
                selection:
                    $plan.intent.pace
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


            styleDescription(
                plan
                    .intent
                    .pace
                    .subtitle
            )


            // MARK: Start Preference

            Picker(
                "Start with",
                selection:
                    $plan
                        .intent
                        .startPreference
            ) {

                ForEach(
                    StartPreference
                        .allCases
                ) {
                    preference in

                    Text(
                        preference.title
                    )
                    .tag(
                        preference
                    )
                }
            }


            styleDescription(
                plan
                    .intent
                    .startPreference
                    .subtitle
            )


            // MARK: Optimization

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


            styleDescription(
                plan
                    .intent
                    .optimizationGoal
                    .subtitle
            )

        } header: {

            Label(
                "Today's Style",
                systemImage:
                    "slider.horizontal.3"
            )

        } footer: {

            Text(
                finishTimeFooter
            )
        }
    }


    // MARK: - Style Description

    private func styleDescription(
        _ text: String
    ) -> some View {

        Text(text)
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
    }


    // MARK: - Finish Time Footer

    private var finishTimeFooter:
        String {

        if plan.intent.finishBy
            <=
            plan.intent.dayStart {

            return "Finish time is treated as the following day. For example, 5 PM → 1 AM is supported."
        }


        return "Halfway will use this window when building your schedule."
    }


    // MARK: - Summary Section

    private var planSummarySection:
        some View {

        Section {

            HStack {

                Label(
                    "Must-visits",
                    systemImage:
                        "heart.fill"
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

                Label(
                    "Flexible stops",
                    systemImage:
                        "wand.and.stars"
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

                Label(
                    "Day",
                    systemImage:
                        "clock"
                )


                Spacer()


                Text(
                    dayWindowText
                )
                .foregroundStyle(
                    .secondary
                )
            }


            HStack {

                Label(
                    "Pace",
                    systemImage:
                        "figure.walk"
                )


                Spacer()


                Text(
                    plan
                        .intent
                        .pace
                        .title
                )
                .foregroundStyle(
                    .secondary
                )
            }


            if !plan.flexibleStops
                .isEmpty {

                flexibleTimeSummary
            }

        } header: {

            Text(
                "Plan Summary"
            )
        }
    }


    // MARK: - Flexible Time Summary

    private var flexibleTimeSummary:
        some View {

        VStack(
            alignment: .leading,
            spacing: 9
        ) {

            Text(
                "Timing"
            )
            .font(
                .caption
                    .weight(.semibold)
            )
            .foregroundStyle(
                .secondary
            )


            ForEach(
                plan.flexibleStops
            ) {
                stop in

                HStack(
                    spacing: 8
                ) {

                    Image(
                        systemName:
                            stop
                                .category
                                .icon
                    )
                    .frame(
                        width: 18
                    )


                    Text(
                        flexibleStopName(
                            stop
                        )
                    )
                    .lineLimit(1)


                    Spacer()


                    Text(
                        timeText(
                            for:
                                stop
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


    // MARK: - Build Button

    private var buildButton:
        some View {

        VStack(spacing: 0) {

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
                plan.anchors.isEmpty
                &&
                plan.flexibleStops.isEmpty
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

        HStack(
            spacing: 12
        ) {

            ZStack {

                Circle()
                    .fill(
                        Color.accentColor
                    )
                    .frame(
                        width: 30,
                        height: 30
                    )


                Text(
                    "\(index + 1)"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .white
                )
            }


            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(
                    anchor.place.name
                )
                .font(
                    .body
                        .weight(.medium)
                )


                let address =
                    anchor
                        .place
                        .mapItem
                        .halfwayAddressText


                if !address.isEmpty {

                    Text(
                        address
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(1)
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
        .padding(
            .vertical,
            3
        )
    }


    // MARK: - Add Anchor

    private func addAnchor(
        _ mapItem:
            MKMapItem
    ) {

        let newPlace =
            PlannedPlace(
                mapItem:
                    mapItem
            )


        let exists =
            plan.anchors.contains {
                anchor in

                let existing =
                    anchor
                        .place
                        .coordinate


                let incoming =
                    newPlace
                        .coordinate


                return
                    abs(
                        existing.latitude
                        -
                        incoming.latitude
                    )
                    <
                    0.00001
                    &&
                    abs(
                        existing.longitude
                        -
                        incoming.longitude
                    )
                    <
                    0.00001
            }


        if !exists {

            plan.anchors.append(
                AnchorStop(
                    place:
                        newPlace
                )
            )
        }


        searchService.clear()


        isAddingAnchor =
            false
    }


    // MARK: - Remove Anchor

    private func removeAnchor(
        _ anchor:
            AnchorStop
    ) {

        plan.anchors.removeAll {

            $0.id == anchor.id
        }
    }


    // MARK: - Add Flexible Stop

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
    }


    // MARK: - Remove Flexible Stop

    private func removeFlexibleStop(
        id: UUID
    ) {

        plan.flexibleStops.removeAll {

            $0.id == id
        }
    }


    // MARK: - Flexible Stop Display Name

    private func flexibleStopName(
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


    // MARK: - Time Text

    private func timeText(
        for stop:
            FlexibleStop
    ) -> String {

        if stop.timePreference
            ==
            .specific {

            return stop
                .specificTime
                .formatted(
                    date: .omitted,
                    time: .shortened
                )
        }


        return stop
            .timePreference
            .title
    }


    // MARK: - Day Window

    private var dayWindowText:
        String {

        let start =
            plan.intent
                .dayStart
                .formatted(
                    date: .omitted,
                    time: .shortened
                )


        let finish =
            plan.intent
                .finishBy
                .formatted(
                    date: .omitted,
                    time: .shortened
                )


        return "\(start) – \(finish)"
    }


    // MARK: - Duration Formatting

    private func formatMinutes(
        _ minutes: Int
    ) -> String {

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
