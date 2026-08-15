import SwiftUI
import MapKit
import CoreLocation


struct PlanSetupView: View {

    @Binding
    var plan: PlanRequest

    @ObservedObject
    var searchService: PlaceSearchService

    let userLocation: CLLocation?

    let onBuild: () -> Void


    @Environment(\.dismiss)
    private var dismiss


    @State
    private var isAddingAnchor = false


    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Must Visit

                Section {

                    if plan.anchors.isEmpty {

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text("No fixed places yet")
                                .font(
                                    .subheadline.weight(
                                        .medium
                                    )
                                )

                            Text(
                                "Add somewhere you definitely want to visit."
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
                                plan.anchors.enumerated()
                            ),
                            id: \.element.id
                        ) {
                            index,
                            anchor in

                            anchorRow(
                                anchor,
                                index: index
                            )
                        }
                    }


                    Button {

                        isAddingAnchor = true

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
                        "These are specific places you already know you want to visit."
                    )
                }


                // MARK: - Flexible Stops

                Section {

                    if plan.flexibleStops.isEmpty {

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text(
                                "Nothing flexible yet"
                            )
                            .font(
                                .subheadline.weight(
                                    .medium
                                )
                            )


                            Text(
                                "Add things like lunch, coffee, dessert, or an activity. Halfway will choose the actual place later."
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

                            flexibleStopRow(
                                stop: $stop
                            )
                        }
                    }


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

                } header: {

                    Label(
                        "I Also Want To...",
                        systemImage:
                            "sparkles"
                    )

                } footer: {

                    Text(
                        "You choose what you want to do. The planning engine will later find the real place that best fits the route."
                    )
                }


                // MARK: - Preferences

                Section {

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


                    preferenceDescription(
                        plan.intent
                            .startPreference
                            .subtitle
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
                            .tag(goal)
                        }
                    }


                    preferenceDescription(
                        plan.intent
                            .optimizationGoal
                            .subtitle
                    )

                } header: {

                    Label(
                        "Today's Style",
                        systemImage:
                            "slider.horizontal.3"
                    )
                }


                // MARK: - Current Plan Summary

                Section {

                    HStack {

                        Label(
                            "Fixed places",
                            systemImage:
                                "mappin.circle.fill"
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
                            "Start",
                            systemImage:
                                "play.fill"
                        )

                        Spacer()

                        Text(
                            plan.intent
                                .startPreference
                                .title
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    HStack {

                        Label(
                            "Goal",
                            systemImage:
                                "scope"
                        )

                        Spacer()

                        Text(
                            plan.intent
                                .optimizationGoal
                                .title
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                } header: {

                    Text("Plan Summary")
                }
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


    // MARK: - Anchor Row

    private func anchorRow(
        _ anchor: AnchorStop,
        index: Int
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
                    .body.weight(
                        .medium
                    )
                )


                let address =
                    anchor
                        .place
                        .mapItem
                        .halfwayAddressText


                if !address.isEmpty {

                    Text(address)
                        .font(
                            .caption
                        )
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


    // MARK: - Flexible Stop Row

    private func flexibleStopRow(
        stop: Binding<FlexibleStop>
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack(
                spacing: 10
            ) {

                Image(
                    systemName:
                        stop.wrappedValue
                            .category
                            .icon
                )
                .frame(
                    width: 26
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
                        .tag(category)
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
                stop.wrappedValue
                    .category
                    .placeholder,

                text:
                    stop.query
            )
            .textInputAutocapitalization(
                .sentences
            )
        }
        .padding(
            .vertical,
            4
        )
    }


    // MARK: - Description

    private func preferenceDescription(
        _ text: String
    ) -> some View {

        Text(text)
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
    }


    // MARK: - Build Button

    private var buildButton: some View {

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


    // MARK: - Add Anchor

    private func addAnchor(
        _ mapItem: MKMapItem
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
                    anchor.place.coordinate

                let incoming =
                    newPlace.coordinate


                return
                    abs(
                        existing.latitude
                        -
                        incoming.latitude
                    )
                    < 0.00001
                    &&
                    abs(
                        existing.longitude
                        -
                        incoming.longitude
                    )
                    < 0.00001
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
        _ anchor: AnchorStop
    ) {

        plan.anchors.removeAll {

            $0.id == anchor.id
        }
    }


    // MARK: - Flexible Stop

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


    private func removeFlexibleStop(
        id: UUID
    ) {

        plan.flexibleStops.removeAll {

            $0.id == id
        }
    }
}
