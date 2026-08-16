import SwiftUI
import MapKit
import CoreLocation


struct PlaceSearchView: View {

    // MARK: - Dependencies

    @ObservedObject
    var searchService: PlaceSearchService

    let referencePlace: PlannedPlace?

    let userLocation: CLLocation?

    let onPlaceSelected: (MKMapItem) -> Void


    // MARK: - Environment

    @Environment(\.dismiss)
    private var dismiss


    // MARK: - Focus

    @FocusState
    private var searchFocused: Bool


    // MARK: - Body

    var body: some View {

        NavigationStack {

            VStack(spacing: 0) {

                searchField


                if trimmedQuery.isEmpty {

                    emptyState

                } else if
                    searchService.isSearching
                    &&
                    searchService.results.isEmpty {

                    loadingState

                } else if searchService.results.isEmpty {

                    noResultsState

                } else {

                    searchResults
                }
            }
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button("Done") {

                        searchService.clear()

                        dismiss()
                    }
                }
            }
            .task {

                searchService.setReference(
                    place: referencePlace,
                    userLocation: userLocation
                )

                searchFocused = true
            }
        }
    }


    // MARK: - Query

    private var trimmedQuery: String {

        searchService
            .query
            .trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
            )
    }


    // MARK: - Search Field

    private var searchField: some View {

        HStack(spacing: 10) {

            Image(
                systemName: "magnifyingglass"
            )
            .foregroundStyle(.secondary)


            TextField(
                "Search any place...",
                text: $searchService.query
            )
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()


            if searchService.isSearching {

                ProgressView()
                    .controlSize(.small)

            } else if !searchService.query.isEmpty {

                Button {

                    searchService.clear()

                } label: {

                    Image(
                        systemName: "xmark.circle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Color.secondary.opacity(0.12)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }


    // MARK: - Search Results

    private var searchResults: some View {

        VStack(spacing: 0) {

            resultHeader

            Divider()


            List {

                ForEach(
                    Array(
                        searchService
                            .results
                            .enumerated()
                    ),
                    id: \.element.id
                ) { index, result in

                    searchResultRow(
                        result: result,
                        index: index
                    )
                }
            }
            .listStyle(.plain)
        }
    }


    // MARK: - Results Header

    private var resultHeader: some View {

        HStack(spacing: 7) {

            Image(
                systemName: "magnifyingglass"
            )
            .font(.caption)


            Text(
                "Results near \(searchService.referenceName)"
            )
            .font(
                .caption.weight(.medium)
            )


            Spacer()


            Text("MAPS + DISTANCE")
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }


    // MARK: - Search Result Row

    private func searchResultRow(
        result: PlaceSearchResult,
        index: Int
    ) -> some View {

        Button {

            onPlaceSelected(
                result.mapItem
            )

        } label: {

            HStack(
                alignment: .center,
                spacing: 12
            ) {

                resultIcon(
                    result: result,
                    index: index
                )


                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    resultNameRow(
                        result: result,
                        index: index
                    )


                    addressView(
                        result: result
                    )


                    distanceView(
                        result: result,
                        index: index
                    )
                }


                Spacer()


                Image(
                    systemName: "chevron.right"
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }


    // MARK: - Result Icon

    private func resultIcon(
        result: PlaceSearchResult,
        index: Int
    ) -> some View {

        let isFirst =
            index == 0


        return Image(
            systemName:
                isFirst
                ? "location.circle.fill"
                : "mappin.and.ellipse"
        )
        .font(
            .system(size: 21)
        )
        .frame(width: 32)
    }


    // MARK: - Name + Badge

    private func resultNameRow(
        result: PlaceSearchResult,
        index: Int
    ) -> some View {

        HStack(spacing: 7) {

            Text(
                result.mapItem.name
                ??
                "Unnamed Place"
            )
            .font(
                .body.weight(.semibold)
            )
            .foregroundStyle(.primary)
            .lineLimit(1)


            if index == 0 {

                Text(topBadgeText)
                    .font(
                        .system(
                            size: 9,
                            weight: .bold
                        )
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Color.primary.opacity(0.08)
                    )
                    .clipShape(
                        Capsule()
                    )
            }
        }
    }


    // MARK: - Top Result Badge

    private var topBadgeText: String {

        let results =
            searchService.results


        guard results.count >= 2 else {

            return "BEST MATCH"
        }


        let firstName =
            normalizedName(
                results[0]
                    .mapItem
                    .name
                ??
                ""
            )


        let secondName =
            normalizedName(
                results[1]
                    .mapItem
                    .name
                ??
                ""
            )


        /*
         Same exact business/place name:

         Tatte Bakery & Cafe
         Tatte Bakery & Cafe

         → our service orders branches
           by distance.
         */

        if !firstName.isEmpty
            &&
            firstName == secondName {

            return "CLOSEST"
        }


        /*
         Different result names:

         Apple's search/completion ranking
         determines the top interpretation.

         Example:
         "MFA"
         → Museum of Fine Arts
         */

        return "BEST MATCH"
    }


    // MARK: - Address

    @ViewBuilder
    private func addressView(
        result: PlaceSearchResult
    ) -> some View {

        let address =
            cleanAddress(
                for: result.mapItem
            )


        if !address.isEmpty {

            Text(address)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }


    // MARK: - Distance

    @ViewBuilder
    private func distanceView(
        result: PlaceSearchResult,
        index: Int
    ) -> some View {

        if let distance =
            result.distanceMeters {

            HStack(spacing: 5) {

                Image(
                    systemName: "location.fill"
                )
                .font(
                    .system(size: 10)
                )


                Text(
                    "\(formatDistance(distance)) from \(searchService.referenceName)"
                )
                .font(
                    .caption.weight(
                        index == 0
                        ? .semibold
                        : .regular
                    )
                )
            }
            .foregroundStyle(
                index == 0
                ? .primary
                : .secondary
            )
        }
    }


    // MARK: - Clean Address

    private func cleanAddress(
        for mapItem: MKMapItem
    ) -> String {

        var address =
            mapItem.halfwayAddressText


        guard
            let name = mapItem.name,
            !name.isEmpty
        else {

            return address
        }


        /*
         Some address strings can contain:

         "Tatte Bakery & Cafe,
          399 Boylston St..."

         Remove duplicated place name.
         */

        let prefix =
            "\(name), "


        if address.hasPrefix(prefix) {

            address =
                String(
                    address.dropFirst(
                        prefix.count
                    )
                )
        }


        return address
    }


    // MARK: - Distance Formatter

    private func formatDistance(
        _ meters: CLLocationDistance
    ) -> String {

        if meters < 100 {

            return "<0.1 km"
        }


        let kilometers =
            meters / 1000


        if kilometers < 10 {

            return String(
                format: "%.1f km",
                kilometers
            )
        }


        return String(
            format: "%.0f km",
            kilometers
        )
    }


    // MARK: - Normalize Name

    private func normalizedName(
        _ value: String
    ) -> String {

        value
            .folding(
                options: [
                    .caseInsensitive,
                    .diacriticInsensitive
                ],
                locale: .current
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
                separator: " "
            )
    }


    // MARK: - Empty State

    private var emptyState: some View {

        VStack(spacing: 14) {

            Spacer()


            Image(
                systemName: "map.fill"
            )
            .font(
                .system(size: 40)
            )
            .foregroundStyle(.secondary)


            if let referencePlace {

                Text("What's next?")
                    .font(
                        .title3.bold()
                    )


                Text(
                    "Search from \(referencePlace.name). You can type a place name, abbreviation, or search phrase."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            } else {

                Text(
                    "Where do you want to go?"
                )
                .font(
                    .title3.bold()
                )


                Text(
                    "Type a place name, abbreviation, or search phrase."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }


            Spacer()
        }
        .padding()
    }


    // MARK: - Loading State

    private var loadingState: some View {

        VStack(spacing: 14) {

            Spacer()


            ProgressView()


            Text(
                "Searching Apple Maps..."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)


            Spacer()
        }
    }


    // MARK: - No Results State

    private var noResultsState: some View {

        VStack(spacing: 12) {

            Spacer()


            Image(
                systemName: "magnifyingglass"
            )
            .font(
                .system(size: 34)
            )
            .foregroundStyle(.secondary)


            Text(
                searchService.searchMessage == nil
                ? "No places found"
                : "Search paused"
            )
            .font(.headline)


            Text(
                searchService.searchMessage
                ??
                "Try another spelling, abbreviation, or search phrase."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)


            Spacer()
        }
        .padding()
    }
}


// MARK: - Preview

#Preview {

    ContentView()
}
