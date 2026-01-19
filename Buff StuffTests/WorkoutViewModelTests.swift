//
//  WorkoutViewModelTests.swift
//  Buff StuffTests
//
//  Unit tests for WorkoutViewModel core functionality
//

import XCTest
@testable import Buff_Stuff

@MainActor
final class WorkoutViewModelTests: XCTestCase {

    var viewModel: WorkoutViewModel!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = WorkoutViewModel()
        // Clear any existing data for clean tests
        viewModel.workouts.removeAll()
        viewModel.activeWorkout = nil
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Workout Lifecycle Tests

    func testStartWorkout_CreatesActiveWorkout() {
        // Given: No active workout
        XCTAssertNil(viewModel.activeWorkout)

        // When: Start workout
        viewModel.startWorkout()

        // Then: Active workout exists
        XCTAssertNotNil(viewModel.activeWorkout)
        XCTAssertTrue(viewModel.activeWorkout?.isActive ?? false)
    }

    func testFinishWorkout_MovesToHistory() {
        // Given: Active workout
        viewModel.startWorkout()
        let initialCount = viewModel.workouts.count

        // When: Finish workout
        viewModel.finishWorkout()

        // Then: No active workout, added to history
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(viewModel.workouts.count, initialCount + 1)
    }

    func testCancelWorkout_DoesNotSaveToHistory() {
        // Given: Active workout
        viewModel.startWorkout()
        let initialCount = viewModel.workouts.count

        // When: Cancel workout
        viewModel.cancelWorkout()

        // Then: No active workout, history unchanged
        XCTAssertNil(viewModel.activeWorkout)
        XCTAssertEqual(viewModel.workouts.count, initialCount)
    }

    // MARK: - Set Logging Tests

    func testLogSet_AddsSetToActiveWorkout() {
        // Given: An exercise
        let exercise = Exercise(
            name: "Test Exercise",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 100,
            defaultReps: 8
        )
        viewModel.exercises.append(exercise)

        // When: Log a set (auto-starts workout)
        viewModel.logSet(for: exercise, weight: 135, reps: 10)

        // Then: Workout has the set
        XCTAssertNotNil(viewModel.activeWorkout)
        XCTAssertEqual(viewModel.activeWorkout?.entries.count, 1)
        XCTAssertEqual(viewModel.activeWorkout?.entries.first?.sets.count, 1)
        XCTAssertEqual(viewModel.activeWorkout?.entries.first?.sets.first?.weight, 135)
        XCTAssertEqual(viewModel.activeWorkout?.entries.first?.sets.first?.reps, 10)
    }

    func testLogSet_WarmupExcludedFromVolume() {
        // Given: An exercise
        let exercise = Exercise(
            name: "Test Exercise",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 100,
            defaultReps: 8
        )
        viewModel.exercises.append(exercise)

        // When: Log a warmup set and a working set
        viewModel.logSet(for: exercise, weight: 100, reps: 10, isWarmup: true)  // 1000 volume (excluded)
        viewModel.logSet(for: exercise, weight: 135, reps: 8, isWarmup: false)  // 1080 volume (counted)

        // Then: Warmup is marked, entry totalVolume excludes warmups
        let entry = viewModel.activeWorkout?.entries.first
        let warmupSet = entry?.sets.first
        XCTAssertTrue(warmupSet?.isWarmup ?? false)
        XCTAssertEqual(entry?.totalVolume, 1080)  // Only working set counted
        XCTAssertEqual(entry?.workingSets.count, 1)
        XCTAssertEqual(entry?.warmupSets.count, 1)
    }

    func testLogMultipleSets_SameExercise_GroupedInEntry() {
        // Given: An exercise
        let exercise = Exercise(
            name: "Test Exercise",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 100,
            defaultReps: 8
        )
        viewModel.exercises.append(exercise)

        // When: Log multiple sets
        viewModel.logSet(for: exercise, weight: 135, reps: 8)
        viewModel.logSet(for: exercise, weight: 135, reps: 8)
        viewModel.logSet(for: exercise, weight: 135, reps: 6)

        // Then: All sets in one entry
        XCTAssertEqual(viewModel.activeWorkout?.entries.count, 1)
        XCTAssertEqual(viewModel.activeWorkout?.entries.first?.sets.count, 3)
    }

    // MARK: - Exercise Management Tests

    func testAddExercise_IncreasesCount() {
        // Given: Initial count
        let initialCount = viewModel.exercises.count

        // When: Add exercise
        let exercise = Exercise(
            name: "New Exercise",
            muscleGroup: .back,
            equipment: .dumbbell,
            defaultWeight: 50,
            defaultReps: 12
        )
        viewModel.addExercise(exercise)

        // Then: Count increased
        XCTAssertEqual(viewModel.exercises.count, initialCount + 1)
    }

    func testToggleFavorite_FlipsFlag() {
        // Given: Non-favorite exercise
        var exercise = Exercise(
            name: "Test Exercise",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 100,
            defaultReps: 8
        )
        exercise.isFavorite = false
        viewModel.exercises.append(exercise)

        // When: Toggle favorite
        viewModel.toggleFavorite(exercise)

        // Then: Is now favorite
        let updated = viewModel.exercises.first { $0.id == exercise.id }
        XCTAssertTrue(updated?.isFavorite ?? false)
    }

    // MARK: - Volume Calculation Tests

    func testWorkoutTotalVolume_SumsWorkingSets() {
        // Given: Workout with sets
        let exercise = Exercise(
            name: "Test Exercise",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 100,
            defaultReps: 8
        )
        viewModel.exercises.append(exercise)

        viewModel.logSet(for: exercise, weight: 100, reps: 10, isWarmup: true) // 0 volume
        viewModel.logSet(for: exercise, weight: 135, reps: 8) // 1080 volume
        viewModel.logSet(for: exercise, weight: 135, reps: 8) // 1080 volume

        // Then: Total volume excludes warmup
        XCTAssertEqual(viewModel.activeWorkout?.totalVolume, 2160)
    }
}
