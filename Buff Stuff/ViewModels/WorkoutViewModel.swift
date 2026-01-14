import Foundation
import SwiftUI
import Observation

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
}
