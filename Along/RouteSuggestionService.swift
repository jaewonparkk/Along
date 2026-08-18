import Foundation
import MapKit
import CoreLocation
import Combine

struct RouteSuggestion: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let category: FlexibleStopCategory
    let insertionIndex: Int
    let addedDistance: CLLocationDistance
    let isSaved: Bool

    init(
        mapItem: MKMapItem,
        category: FlexibleStopCategory,
        insertionIndex: Int,
        addedDistance: CLLocationDistance,
        isSaved: Bool = false
    ) {
        self.mapItem = mapItem
        self.category = category
        self.insertionIndex = insertionIndex
        self.addedDistance = addedDistance
        self.isSaved = isSaved
    }
}

@MainActor
final class RouteSuggestionService: ObservableObject {
    @Published private(set) var suggestions: [RouteSuggestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private var activeSearch: MKLocalSearch?

    func search(
        category: FlexibleStopCategory,
        along places: [PlannedPlace],
        savedPlaces: [SavedPlaceSnapshot] = []
    ) {
        activeSearch?.cancel()
        suggestions = []
        message = nil
        isLoading = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query(for: category)
        if let region = routeRegion(for: places) {
            request.region = region
        }
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        activeSearch = search

        let savedSuggestions = savedPlaces
            .filter { $0.category == category }
            .map { saved -> RouteSuggestion in
                let item = saved.plannedPlace.mapItem
                let placement = bestInsertion(for: item, in: places)
                return RouteSuggestion(
                    mapItem: item,
                    category: category,
                    insertionIndex: placement.index,
                    addedDistance: placement.detour,
                    isSaved: true
                )
            }
            .filter { $0.addedDistance <= 5_000 }
            .sorted { $0.addedDistance < $1.addedDistance }

        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self, self.activeSearch === search else { return }
                self.activeSearch = nil
                self.isLoading = false

                if error != nil, savedSuggestions.isEmpty {
                    self.message = "Suggestions are temporarily unavailable. Try again in a moment."
                    return
                }

                let ranked = (response?.mapItems ?? []).map { item -> RouteSuggestion in
                    let placement = self.bestInsertion(for: item, in: places)
                    return RouteSuggestion(
                        mapItem: item,
                        category: category,
                        insertionIndex: placement.index,
                        addedDistance: placement.detour
                    )
                }
                .sorted { $0.addedDistance < $1.addedDistance }

                let savedKeys = Set(savedSuggestions.map { self.suggestionKey($0.mapItem) })
                let newSuggestions = ranked.filter {
                    !savedKeys.contains(self.suggestionKey($0.mapItem))
                }

                self.suggestions = Array((savedSuggestions + newSuggestions).prefix(5))
                if self.suggestions.isEmpty {
                    self.message = "No good matches were found along this route."
                }
            }
        }
    }

    private func suggestionKey(_ item: MKMapItem) -> String {
        String(
            format: "%.5f,%.5f",
            item.alongCoordinate.latitude,
            item.alongCoordinate.longitude
        )
    }

    private func query(for category: FlexibleStopCategory) -> String {
        switch category {
        case .food: return "restaurant"
        case .coffee: return "coffee shop"
        case .shopping: return "shopping"
        case .activity: return "things to do"
        default: return category.title
        }
    }

    private func routeRegion(for places: [PlannedPlace]) -> MKCoordinateRegion? {
        guard !places.isEmpty else { return nil }
        let coordinates = places.map(\.coordinate)
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.02, (maxLat - minLat) * 1.5),
                longitudeDelta: max(0.02, (maxLon - minLon) * 1.5)
            )
        )
    }

    private func bestInsertion(
        for item: MKMapItem,
        in places: [PlannedPlace]
    ) -> (index: Int, detour: CLLocationDistance) {
        guard !places.isEmpty else { return (0, 0) }
        let point = CLLocation(latitude: item.alongCoordinate.latitude,
                               longitude: item.alongCoordinate.longitude)

        if places.count == 1 {
            return (1, point.distance(from: location(of: places[0])))
        }

        var best = (index: places.count, detour: CLLocationDistance.greatestFiniteMagnitude)
        for index in 0..<(places.count - 1) {
            let from = location(of: places[index])
            let to = location(of: places[index + 1])
            let detour = from.distance(from: point) + point.distance(from: to) - from.distance(from: to)
            if detour < best.detour { best = (index + 1, detour) }
        }
        return best
    }

    private func location(of place: PlannedPlace) -> CLLocation {
        CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
    }
}
