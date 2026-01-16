import Foundation
import SwiftUI
import Observation

// MARK: - Progress Time Period
enum ProgressTimePeriod: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case threeMonths = "90D"
    case allTime = "ALL"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .allTime: return nil
        }
    }

    var startDate: Date? {
        guard let days = days else { return nil }
        return Calendar.current.date(byAdding: .day, value: -days, to: Date())
    }
}

// MARK: - Progress Status
enum ProgressStatus {
    case progressing  // ↑ >2% volume increase
    case plateau      // → -2% to +2% change
    case declining    // ↓ >2% volume decrease
    case newExercise  // ★ <4 data points to compare

    var icon: String {
        switch self {
        case .progressing: return "arrow.up"
        case .plateau: return "arrow.right"
        case .declining: return "arrow.down"
        case .newExercise: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .progressing: return Theme.Colors.success
        case .plateau: return Theme.Colors.warning
        case .declining: return Theme.Colors.danger
        case .newExercise: return Theme.Colors.textMuted
        }
    }
}

// MARK: - Exercise Progress
struct ExerciseProgress: Identifiable {
    let id: UUID  // exercise ID
    let exercise: Exercise
    let status: ProgressStatus
    // Volume tracking (weight × reps)
    let baselineVolume: Double
    let recentVolume: Double
    let percentChange: Double
    // For expanded view breakdown
    let recentWeight: Double
    let recentReps: Int
    let dataPoints: Int
}

// MARK: - Workout View Model
@MainActor
@Observable
class WorkoutViewModel {
    // MARK: - State
    var exercises: [Exercise] = []
    var workouts: [Workout] = []
    var activeWorkout: Workout?

    // Quick log state
    var selectedExercise: Exercise?
    var quickLogWeight: Double = 0
    var quickLogReps: Int = 0
    var showingQuickLog: Bool = false
    var showingExercisePicker: Bool = false
    var showingNewExercise: Bool = false

    // User Defaults keys
    private let exercisesKey = "buff_stuff_exercises"
    private let workoutsKey = "buff_stuff_workouts"
    private let activeWorkoutKey = "buff_stuff_active_workout"

    // MARK: - Initialization
    init() {
        loadData()

        // If no exercises, add samples
        if exercises.isEmpty {
            exercises = Exercise.samples
            saveExercises()
        }
    }

    // MARK: - Data Persistence
    private func loadData() {
        // Load exercises
        if let data = UserDefaults.standard.data(forKey: exercisesKey),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = decoded
        }

        // Load workouts
        if let data = UserDefaults.standard.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded.sorted { $0.startedAt > $1.startedAt }
        }

        // Load active workout
        if let data = UserDefaults.standard.data(forKey: activeWorkoutKey),
           let decoded = try? JSONDecoder().decode(Workout.self, from: data) {
            activeWorkout = decoded
        }
    }

    private func saveExercises() {
        if let encoded = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: exercisesKey)
        }
    }

    private func saveWorkouts() {
        if let encoded = try? JSONEncoder().encode(workouts) {
            UserDefaults.standard.set(encoded, forKey: workoutsKey)
        }
    }

    private func saveActiveWorkout() {
        if let workout = activeWorkout,
           let encoded = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(encoded, forKey: activeWorkoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
        }
    }

    // MARK: - Workout Management
    func startWorkout() {
        activeWorkout = Workout()
        saveActiveWorkout()
        triggerHaptic(.medium)
    }

    func finishWorkout() {
        guard var workout = activeWorkout else { return }
        workout.completedAt = Date()
        workouts.insert(workout, at: 0)
        activeWorkout = nil
        saveWorkouts()
        saveActiveWorkout()
        triggerHaptic(.success)
    }

    func cancelWorkout() {
        activeWorkout = nil
        saveActiveWorkout()
    }

    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        saveWorkouts()
        triggerHaptic(.light)
    }

    // MARK: - Exercise Management
    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
        saveExercises()
        triggerHaptic(.light)
    }

    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
            saveExercises()
        }
    }

    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
        saveExercises()
    }

    func toggleFavorite(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index].isFavorite.toggle()
            saveExercises()
            triggerHaptic(.light)
        }
    }

    // MARK: - Quick Logging
    func prepareQuickLog(for exercise: Exercise) {
        selectedExercise = exercise

        // Get last set values or defaults
        if let entry = activeWorkout?.entries.first(where: { $0.exercise.id == exercise.id }),
           let lastSet = entry.sets.last {
            quickLogWeight = lastSet.weight
            quickLogReps = lastSet.reps
        } else {
            quickLogWeight = exercise.defaultWeight
            quickLogReps = exercise.defaultReps
        }

        showingQuickLog = true
    }

    func logSet() {
        guard let exercise = selectedExercise else { return }
        logSet(for: exercise, weight: quickLogWeight, reps: quickLogReps)
        showingQuickLog = false
    }

    func logSet(for exercise: Exercise, weight: Double, reps: Int, isWarmup: Bool = false) {
        // Start workout if not active
        if activeWorkout == nil {
            startWorkout()
        }

        guard var workout = activeWorkout else { return }

        let newSet = WorkoutSet(
            exerciseId: exercise.id,
            weight: weight,
            reps: reps,
            isWarmup: isWarmup
        )

        // Find or create exercise entry
        if let entryIndex = workout.entries.firstIndex(where: { $0.exercise.id == exercise.id }) {
            workout.entries[entryIndex].sets.append(newSet)
        } else {
            var entry = ExerciseEntry(exercise: exercise)
            entry.sets.append(newSet)
            workout.entries.append(entry)
        }

        activeWorkout = workout
        saveActiveWorkout()
        triggerHaptic(.success)

        // Update exercise defaults for next time
        if var ex = exercises.first(where: { $0.id == exercise.id }) {
            ex.defaultWeight = weight
            ex.defaultReps = reps
            updateExercise(ex)
        }
    }

    // Quick repeat last set for an exercise
    func repeatLastSet(for exercise: Exercise) {
        guard let entry = activeWorkout?.entries.first(where: { $0.exercise.id == exercise.id }),
              let lastSet = entry.sets.last else {
            // No previous set, use defaults
            logSet(for: exercise, weight: exercise.defaultWeight, reps: exercise.defaultReps)
            return
        }

        logSet(for: exercise, weight: lastSet.weight, reps: lastSet.reps)
    }

    func deleteSet(_ set: WorkoutSet, from exerciseId: UUID) {
        guard var workout = activeWorkout,
              let entryIndex = workout.entries.firstIndex(where: { $0.exercise.id == exerciseId }) else { return }

        workout.entries[entryIndex].sets.removeAll { $0.id == set.id }

        // Remove entry if no sets left
        if workout.entries[entryIndex].sets.isEmpty {
            workout.entries.remove(at: entryIndex)
        }

        activeWorkout = workout
        saveActiveWorkout()
        triggerHaptic(.light)
    }

    // MARK: - Helpers
    func recentExercises(limit: Int = 5) -> [Exercise] {
        guard let workout = activeWorkout else {
            // Return favorites first, then by creation date
            return exercises
                .sorted { ($0.isFavorite ? 0 : 1, $0.createdAt) < ($1.isFavorite ? 0 : 1, $1.createdAt) }
                .prefix(limit)
                .map { $0 }
        }

        // Return exercises used in current workout first
        let usedIds = Set(workout.entries.map { $0.exercise.id })
        let used = workout.entries.map { $0.exercise }
        let unused = exercises.filter { !usedIds.contains($0.id) }
            .sorted { ($0.isFavorite ? 0 : 1) < ($1.isFavorite ? 0 : 1) }
            .prefix(limit - used.count)

        return used + unused
    }

    func exercisesByGroup() -> [(MuscleGroup, [Exercise])] {
        let grouped = Dictionary(grouping: exercises) { $0.muscleGroup }
        return MuscleGroup.allCases.compactMap { group in
            guard let exercises = grouped[group], !exercises.isEmpty else { return nil }
            return (group, exercises.sorted { $0.name < $1.name })
        }
    }

    // MARK: - Haptic Feedback
    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    // MARK: - Progress Data Methods

    /// Returns completed workouts within the specified time period
    func workouts(in period: ProgressTimePeriod) -> [Workout] {
        let completed = workouts.filter { $0.completedAt != nil }
        guard let startDate = period.startDate else {
            return completed
        }
        return completed.filter { $0.startedAt >= startDate }
    }

    /// Returns max weight lifted per workout for a specific exercise
    func exerciseProgressDataPoints(exerciseId: UUID, in period: ProgressTimePeriod) -> [(date: Date, weight: Double)] {
        workouts(in: period)
            .compactMap { workout -> (date: Date, weight: Double)? in
                // Find max non-warmup weight for this exercise in the workout
                guard let entry = workout.entries.first(where: { $0.exercise.id == exerciseId }) else {
                    return nil
                }
                let maxWeight = entry.workingSets.map { $0.weight }.max() ?? 0
                guard maxWeight > 0 else { return nil }
                return (date: workout.startedAt, weight: maxWeight)
            }
            .sorted { $0.date < $1.date }
    }

    /// Returns full data points for a specific exercise (weight, reps, volume per session)
    /// Uses top set (highest volume working set) from each session
    func exerciseProgressDataPointsFull(exerciseId: UUID, in period: ProgressTimePeriod) -> [(date: Date, weight: Double, reps: Int, volume: Double)] {
        workouts(in: period)
            .compactMap { workout -> (date: Date, weight: Double, reps: Int, volume: Double)? in
                guard let entry = workout.entries.first(where: { $0.exercise.id == exerciseId }) else {
                    return nil
                }
                // Find top set by volume (weight × reps)
                guard let topSet = entry.workingSets.max(by: { $0.volume < $1.volume }),
                      topSet.volume > 0 else {
                    return nil
                }
                return (date: workout.startedAt, weight: topSet.weight, reps: topSet.reps, volume: topSet.volume)
            }
            .sorted { $0.date < $1.date }
    }

    /// Returns exercises that have logged history (for the exercise picker)
    func exercisesWithHistory() -> [Exercise] {
        let exerciseIdsWithHistory = Set(
            workouts.flatMap { $0.entries.map { $0.exercise.id } }
        )
        return exercises.filter { exerciseIdsWithHistory.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    /// Stats for a specific time period
    func stats(in period: ProgressTimePeriod) -> (workouts: Int, sets: Int, volume: Double) {
        let periodWorkouts = workouts(in: period)
        let totalSets = periodWorkouts.reduce(0) { $0 + $1.totalSets }
        let totalVolume = periodWorkouts.reduce(0) { $0 + $1.totalVolume }
        return (workouts: periodWorkouts.count, sets: totalSets, volume: totalVolume)
    }

    /// Returns progress status for all exercises with history in the time period
    /// Uses volume (weight × reps) for progress calculation
    func allExerciseProgress(in period: ProgressTimePeriod) -> [ExerciseProgress] {
        let exercisesWithData = exercisesWithHistory()

        return exercisesWithData.compactMap { exercise -> ExerciseProgress? in
            let dataPoints = exerciseProgressDataPointsFull(exerciseId: exercise.id, in: period)

            guard !dataPoints.isEmpty else { return nil }

            // Get most recent data point for display
            let mostRecent = dataPoints.last!

            // Need at least 4 data points to compare baseline vs recent
            if dataPoints.count < 4 {
                let avgVolume = dataPoints.map { $0.volume }.reduce(0, +) / Double(dataPoints.count)
                return ExerciseProgress(
                    id: exercise.id,
                    exercise: exercise,
                    status: .newExercise,
                    baselineVolume: avgVolume,
                    recentVolume: avgVolume,
                    percentChange: 0,
                    recentWeight: mostRecent.weight,
                    recentReps: mostRecent.reps,
                    dataPoints: dataPoints.count
                )
            }

            // Split data: recent 2 sessions vs older sessions (2-4 before that)
            let sortedByDate = dataPoints.sorted { $0.date > $1.date }
            let recentSessions = Array(sortedByDate.prefix(2))
            let olderSessions = Array(sortedByDate.dropFirst(2).prefix(2))

            let recentAvg = recentSessions.map { $0.volume }.reduce(0, +) / Double(recentSessions.count)
            let baselineAvg = olderSessions.map { $0.volume }.reduce(0, +) / Double(olderSessions.count)

            // Calculate percent change
            let percentChange: Double
            if baselineAvg > 0 {
                percentChange = ((recentAvg - baselineAvg) / baselineAvg) * 100
            } else {
                percentChange = 0
            }

            // Determine status based on 2% threshold
            let status: ProgressStatus
            if percentChange > 2 {
                status = .progressing
            } else if percentChange < -2 {
                status = .declining
            } else {
                status = .plateau
            }

            return ExerciseProgress(
                id: exercise.id,
                exercise: exercise,
                status: status,
                baselineVolume: baselineAvg,
                recentVolume: recentAvg,
                percentChange: percentChange,
                recentWeight: mostRecent.weight,
                recentReps: mostRecent.reps,
                dataPoints: dataPoints.count
            )
        }
        .sorted { $0.exercise.name < $1.exercise.name }
    }

    // MARK: - Sample Data Generation (Debug)
    #if DEBUG
    func generateSampleData() {
        // Clear existing workouts
        workouts.removeAll()

        let calendar = Calendar.current

        // Sample workout templates
        let pushExercises = exercises.filter { $0.muscleGroup == .chest || $0.muscleGroup == .shoulders || $0.muscleGroup == .triceps }
        let pullExercises = exercises.filter { $0.muscleGroup == .back || $0.muscleGroup == .biceps }
        let legExercises = exercises.filter { $0.muscleGroup == .legs || $0.muscleGroup == .glutes }

        // Generate workouts over 90 days
        var sampleWorkouts: [Workout] = []

        for weeksAgo in 0..<13 {
            // 3-4 workouts per week
            let workoutsThisWeek = Int.random(in: 3...4)

            for workoutIndex in 0..<workoutsThisWeek {
                let daysAgo = (weeksAgo * 7) + (workoutIndex * 2) + Int.random(in: 0...1)
                guard let workoutDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }

                // Rotate push/pull/legs
                let workoutType = workoutIndex % 3
                let exercisePool: [Exercise]
                switch workoutType {
                case 0: exercisePool = pushExercises.isEmpty ? Array(exercises.prefix(3)) : pushExercises
                case 1: exercisePool = pullExercises.isEmpty ? Array(exercises.prefix(3)) : pullExercises
                default: exercisePool = legExercises.isEmpty ? Array(exercises.prefix(3)) : legExercises
                }

                // Pick 3-4 exercises for this workout
                let selectedExercises = Array(exercisePool.shuffled().prefix(Int.random(in: 3...4)))

                var entries: [ExerciseEntry] = []

                for exercise in selectedExercises {
                    // Progressive overload - weight increases over time
                    let progressFactor = 1.0 + (Double(13 - weeksAgo) * 0.02) // ~2% increase per week
                    let baseWeight = exercise.defaultWeight * progressFactor
                    let weight = baseWeight + Double.random(in: -5...5)

                    var sets: [WorkoutSet] = []

                    // 1 warmup + 3-4 working sets
                    sets.append(WorkoutSet(
                        exerciseId: exercise.id,
                        weight: weight * 0.5,
                        reps: 10,
                        isWarmup: true,
                        completedAt: workoutDate
                    ))

                    let workingSetsCount = Int.random(in: 3...4)
                    for setIndex in 0..<workingSetsCount {
                        let reps = exercise.defaultReps + Int.random(in: -2...2)
                        let setWeight = weight - (Double(setIndex) * 2.5) // Slight fatigue
                        sets.append(WorkoutSet(
                            exerciseId: exercise.id,
                            weight: max(setWeight, exercise.defaultWeight * 0.7),
                            reps: max(reps, 5),
                            isWarmup: false,
                            completedAt: workoutDate.addingTimeInterval(Double(setIndex) * 180)
                        ))
                    }

                    entries.append(ExerciseEntry(
                        exercise: exercise,
                        sets: sets,
                        startedAt: workoutDate
                    ))
                }

                let duration = TimeInterval(Int.random(in: 45...75) * 60)
                let workout = Workout(
                    name: "",
                    entries: entries,
                    startedAt: workoutDate,
                    completedAt: workoutDate.addingTimeInterval(duration)
                )

                sampleWorkouts.append(workout)
            }
        }

        // Sort by date descending
        workouts = sampleWorkouts.sorted { $0.startedAt > $1.startedAt }
        saveWorkouts()
        triggerHaptic(.success)
    }

    func clearAllData() {
        workouts.removeAll()
        activeWorkout = nil
        saveWorkouts()
        saveActiveWorkout()
        triggerHaptic(.warning)
    }
    #endif
}
