import Foundation

// MARK: - Workout Set Model
// A single set of an exercise (weight x reps)
struct WorkoutSet: Identifiable, Codable, Hashable {
    let id: UUID
    let exerciseId: UUID
    var weight: Double
    var reps: Int
    var isWarmup: Bool
    var completedAt: Date
    var notes: String

    // Calculated volume (weight x reps)
    var volume: Double {
        weight * Double(reps)
    }

    init(
        id: UUID = UUID(),
        exerciseId: UUID,
        weight: Double,
        reps: Int,
        isWarmup: Bool = false,
        completedAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.weight = weight
        self.reps = reps
        self.isWarmup = isWarmup
        self.completedAt = completedAt
        self.notes = notes
    }
}

// MARK: - Exercise Entry (groups sets by exercise within a workout)
struct ExerciseEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let exercise: Exercise
    var sets: [WorkoutSet]
    var startedAt: Date

    var totalVolume: Double {
        sets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.volume }
    }

    var workingSets: [WorkoutSet] {
        sets.filter { !$0.isWarmup }
    }

    var warmupSets: [WorkoutSet] {
        sets.filter { $0.isWarmup }
    }

    init(
        id: UUID = UUID(),
        exercise: Exercise,
        sets: [WorkoutSet] = [],
        startedAt: Date = Date()
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.startedAt = startedAt
    }

    // Quick add a set with last values or defaults
    mutating func addSet(weight: Double? = nil, reps: Int? = nil, isWarmup: Bool = false) {
        let lastSet = sets.last
        let newSet = WorkoutSet(
            exerciseId: exercise.id,
            weight: weight ?? lastSet?.weight ?? exercise.defaultWeight,
            reps: reps ?? lastSet?.reps ?? exercise.defaultReps,
            isWarmup: isWarmup
        )
        sets.append(newSet)
    }
}
