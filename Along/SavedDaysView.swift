import SwiftUI
import SwiftData
import MapKit

struct SavedDaysView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedDay.createdAt, order: .reverse) private var days: [SavedDay]

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    ContentUnavailableView(
                        "No Saved Days",
                        systemImage: "bookmark",
                        description: Text("Build a plan and tap Save My Day.")
                    )
                } else {
                    List {
                        ForEach(days) { day in
                            NavigationLink {
                                SavedDayDetailView(day: day)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(day.title)
                                        .font(.headline)
                                    Text(summary(for: day))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(days[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Saved Days")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func summary(for day: SavedDay) -> String {
        let count = day.stops.count
        if let start = day.plannedStart, let end = day.plannedEnd {
            return "\(count) stops • \(clock(start))–\(clock(end))"
        }
        return "\(count) stops"
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct SavedDayDetailView: View {
    let day: SavedDay

    var body: some View {
        List {
            Section {
                ForEach(Array(day.stops.enumerated()), id: \.element.id) { index, stop in
                    Button {
                        openInMaps(stop)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.accentColor, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                if let start = stop.startTime, let end = stop.endTime {
                                    Text("\(clock(start))–\(clock(end))")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                }
                                Text(stop.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if !stop.address.isEmpty {
                                    Text(stop.address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "map")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Tap a place to open it in Apple Maps.")
            }
        }
        .navigationTitle(day.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openInMaps(_ stop: SavedStopRecord) {
        let item = MKMapItem(location: CLLocation(
            latitude: stop.latitude,
            longitude: stop.longitude
        ), address: nil)
        item.name = stop.name
        item.openInMaps()
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

struct SaveDayPrompt: View {
    let defaultTitle: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name your day") {
                    TextField("Saturday in Boston", text: $title)
                }
                Section {
                    Text("Saved only on this device. No account required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Save My Day")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if title.isEmpty { title = defaultTitle } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(clean.isEmpty ? defaultTitle : clean)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
