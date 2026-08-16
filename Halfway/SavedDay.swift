import Foundation
import SwiftData

struct SavedStopRecord: Codable, Identifiable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let startTime: Date?
    let endTime: Date?
}

@Model
final class SavedDay {
    var id: UUID
    var title: String
    var createdAt: Date
    var plannedStart: Date?
    var plannedEnd: Date?
    var stopsData: Data

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        plannedStart: Date?,
        plannedEnd: Date?,
        stops: [SavedStopRecord]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.stopsData = (try? JSONEncoder().encode(stops)) ?? Data()
    }

    var stops: [SavedStopRecord] {
        (try? JSONDecoder().decode([SavedStopRecord].self, from: stopsData)) ?? []
    }
}
