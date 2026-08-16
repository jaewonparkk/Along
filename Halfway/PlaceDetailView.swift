import SwiftUI
import MapKit
import GooglePlaces

enum PlaceDetailOpenStatus {
    case open
    case closed
    case unknown

    init(_ status: GMSPlaceOpenStatus) {
        switch status {
        case .open: self = .open
        case .closed: self = .closed
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}

struct PlaceDetailData {
    let photo: UIImage?
    let todayHours: String?
    let openStatus: PlaceDetailOpenStatus
}

struct PlaceDetailView: View {
    let place: PlannedPlace
    let scheduled: ScheduledStop?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: PlaceDetailData?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    photoHeader

                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name)
                            .font(.title2.bold())

                        let address = place.mapItem.halfwayAddressText
                        if !address.isEmpty {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    statusCard
                    visitCard

                    Button {
                        place.mapItem.openInMaps()
                    } label: {
                        Label("View in Apple Maps", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("Place photo and hours provided by Google.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .navigationTitle("Place Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            detail = await GooglePlacesService.shared.detail(for: place)
        }
    }

    @ViewBuilder
    private var photoHeader: some View {
        if let photo = detail?.photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else if detail == nil {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 210)
                .overlay { ProgressView() }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
                .frame(height: 160)
                .overlay {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Hours", systemImage: "clock")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            Text(detail?.todayHours ?? "Hours not available")
                .font(.subheadline)
                .foregroundStyle(detail?.todayHours == nil ? .secondary : .primary)
        }
        .padding(16)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch detail?.openStatus {
        case .open:
            Label("Open now", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .closed:
            Label("Closed now", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .unknown, .none:
            Text("Status unknown")
                .foregroundStyle(.secondary)
        }
    }

    private var visitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your visit", systemImage: "calendar.badge.clock")
                .font(.headline)

            if let scheduled {
                Text("\(clock(scheduled.startTime))–\(clock(scheduled.departureTime))")
                    .font(.title3.bold())
                Text("Planned stay: \(duration(scheduled.departureTime.timeIntervalSince(scheduled.startTime)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Visit time not available")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes >= 60 && minutes % 60 == 0 { return "\(minutes / 60) hr" }
        if minutes >= 60 { return "\(minutes / 60) hr \(minutes % 60) min" }
        return "\(minutes) min"
    }
}
