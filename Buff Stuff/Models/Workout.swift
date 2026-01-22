import Foundation

// MARK: - Workout Model
// A complete workout session
struct Workout: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var entries: [ExerciseEntry]
    var startedAt: Date
    var completedAt: Date?
    var notes: String

    // Sync properties
    var modifiedAt: Date
    var isDeleted: Bool

    var isActive: Bool {
        completedAt == nil
    }

    var duration: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var totalVolume: Double {
        entries.reduce(0) { $0 + $1.totalVolume }
    }

    var totalSets: Int {
        entries.reduce(0) { $0 + $1.workingSets.count }
    }

    var muscleGroups: [MuscleGroup] {
        Array(Set(entries.map { $0.exercise.muscleGroup })).sorted { $0.rawValue < $1.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        entries: [ExerciseEntry] = [],
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        notes: String = "",
        modifiedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.entries = entries
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.modifiedAt = modifiedAt
        self.isDeleted = isDeleted
    }

    // Custom decoder for backward compatibility with old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        entries = try container.decode([ExerciseEntry].self, forKey: .entries)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        notes = try container.decode(String.self, forKey: .notes)
        // Provide defaults for new sync properties
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? startedAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, entries, startedAt, completedAt, notes, modifiedAt, isDeleted
    }

    // Generate name from exercises if not set
    var displayName: String {
        if !name.isEmpty {
            return name
        }
        let groups = muscleGroups.prefix(3).map { $0.rawValue }
        return groups.isEmpty ? "Workout" : groups.joined(separator: " + ")
    }
}

// MARK: - Date Formatting
extension Workout {
    var dateFormatted: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(startedAt) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(startedAt) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: startedAt)
        }
    }

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startedAt)
    }
}
