import SwiftUI
import CoreLocation

struct RouteOrderSuggestion: Identifiable {
    let id = UUID()
    let places: [PlannedPlace]
    let avoidableDistance: CLLocationDistance
}

enum RouteBacktrackingDetector {
    static func suggestion(
        for places: [PlannedPlace],
        from userLocation: CLLocation?,
        travelMode: TravelMode
    ) -> RouteOrderSuggestion? {
        guard places.count >= 3 else { return nil }

        let optimized = bestNearbyOrder(for: places, from: userLocation)
        guard optimized.map(\.id) != places.map(\.id) else { return nil }

        let currentDistance = pathDistance(places, from: userLocation)
        let optimizedDistance = pathDistance(optimized, from: userLocation)
        let avoidableDistance = currentDistance - optimizedDistance

        let minimumSavings: CLLocationDistance
        switch travelMode {
        case .walking: minimumSavings = 1_200
        case .driving: minimumSavings = 4_000
        case .transit: minimumSavings = 2_500
        }

        guard optimizedDistance > 0,
              currentDistance / optimizedDistance >= 1.3,
              avoidableDistance >= minimumSavings else {
            return nil
        }

        return RouteOrderSuggestion(
            places: optimized,
            avoidableDistance: avoidableDistance
        )
    }

    private static func bestNearbyOrder(
        for places: [PlannedPlace],
        from userLocation: CLLocation?
    ) -> [PlannedPlace] {
        let starts: [Int] = userLocation == nil
            ? Array(places.indices)
            : [places.startIndex]
        var best = places
        var bestDistance = pathDistance(places, from: userLocation)

        for start in starts {
            var remaining = places
            var ordered: [PlannedPlace] = []
            var currentLocation = userLocation

            if currentLocation == nil {
                let first = remaining.remove(at: start)
                ordered.append(first)
                currentLocation = location(for: first)
            }

            while !remaining.isEmpty {
                guard let origin = currentLocation else { break }
                let nearestIndex = remaining.indices.min {
                    origin.distance(from: location(for: remaining[$0]))
                    < origin.distance(from: location(for: remaining[$1]))
                }!
                let next = remaining.remove(at: nearestIndex)
                ordered.append(next)
                currentLocation = location(for: next)
            }

            ordered = improveWithTwoOpt(ordered, from: userLocation)
            let distance = pathDistance(ordered, from: userLocation)
            if distance < bestDistance {
                best = ordered
                bestDistance = distance
            }
        }

        return best
    }

    private static func improveWithTwoOpt(
        _ places: [PlannedPlace],
        from userLocation: CLLocation?
    ) -> [PlannedPlace] {
        guard places.count >= 4 else { return places }
        var best = places
        var improved = true

        while improved {
            improved = false
            let baseline = pathDistance(best, from: userLocation)

            for start in 0..<(best.count - 2) {
                for end in (start + 1)..<best.count {
                    var candidate = best
                    candidate.replaceSubrange(
                        start...end,
                        with: candidate[start...end].reversed()
                    )
                    if pathDistance(candidate, from: userLocation) + 1 < baseline {
                        best = candidate
                        improved = true
                        break
                    }
                }
                if improved { break }
            }
        }

        return best
    }

    private static func pathDistance(
        _ places: [PlannedPlace],
        from userLocation: CLLocation?
    ) -> CLLocationDistance {
        guard !places.isEmpty else { return 0 }
        var total: CLLocationDistance = 0
        var previous = userLocation

        for place in places {
            let next = location(for: place)
            if let previous { total += previous.distance(from: next) }
            previous = next
        }

        return total
    }

    private static func location(for place: PlannedPlace) -> CLLocation {
        CLLocation(
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude
        )
    }
}

struct RouteOrderReviewView: View {
    let suggestion: RouteOrderSuggestion
    let onUseSuggestion: () -> Void
    let onKeepOrder: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "arrow.trianglehead.swap")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 64, height: 64)
                        .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("This route doubles back")
                            .font(.system(size: 30, weight: .bold, design: .rounded))

                        Text("Your order creates a long back-and-forth trip. Along found a smoother order that keeps the same stops and still checks their opening hours.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("SUGGESTED ORDER")
                            .font(.caption2.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 12)

                        ForEach(Array(suggestion.places.enumerated()), id: \.element.id) { index, place in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Color.accentColor, in: Circle())
                                Text(place.name)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 12)

                            if index < suggestion.places.count - 1 { Divider() }
                        }
                    }
                    .padding(18)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))

                    Text("This could avoid about \(formattedDistance) of unnecessary movement.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .padding(24)
            }
            .navigationTitle("Review Your Route")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button("Use Suggested Order", action: onUseSuggestion)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                    Button("Keep My Order", action: onKeepOrder)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.regularMaterial)
            }
        }
    }

    private var formattedDistance: String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(
            from: Measurement(value: suggestion.avoidableDistance, unit: UnitLength.meters)
        )
    }
}
