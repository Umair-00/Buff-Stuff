//
//  SuggestionTests.swift
//  Buff StuffTests
//
//  Unit tests for smart suggestion logic
//

import XCTest
@testable import Buff_Stuff

@MainActor
final class SuggestionTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var testExercise: Exercise!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = WorkoutViewModel()
        viewModel.workouts.removeAll()
        viewModel.exercises.removeAll()

        testExercise = Exercise(
            name: "Bench Press",
            muscleGroup: .chest,
            equipment: .barbell,
            defaultWeight: 135,
            defaultReps: 8,
            weightIncrement: 5
        )
        viewModel.exercises.append(testExercise)
    }

    override func tearDown() async throws {
        viewModel = nil
        testExercise = nil
        try await super.tearDown()
    }

    // MARK: - No History Tests

    func testSuggestion_NoHistory_ReturnsNil() {
        // Given: Exercise with no workout history

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: No suggestion
        XCTAssertNil(suggestion)
    }

    // MARK: - New Exercise Tests

    func testSuggestion_OneSession_ReturnsNewExercise() {
        // Given: Only 1 workout with this exercise
        let workout = createWorkout(weight: 135, reps: 8, daysAgo: 3)
        viewModel.workouts.append(workout)

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: New exercise message
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.type, .newExercise)
    }

    // MARK: - Progressive Overload Tests

    func testSuggestion_ConsistentWeight_SuggestsIncrease() {
        // Given: 2+ sessions at same weight×reps
        viewModel.workouts.append(createWorkout(weight: 185, reps: 8, daysAgo: 7))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 8, daysAgo: 3))

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: Progressive overload suggestion
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.type, .progressiveOverload)
        XCTAssertEqual(suggestion?.suggestedWeight, 190) // 185 + 5 increment
        XCTAssertTrue(suggestion?.message.contains("try 190") ?? false)
    }

    func testSuggestion_ConsistentWeight_ThreeSessions_SuggestsIncrease() {
        // Given: 3 sessions at same weight×reps
        viewModel.workouts.append(createWorkout(weight: 185, reps: 8, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 8, daysAgo: 7))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 8, daysAgo: 2))

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: Progressive overload suggestion mentioning 3 times
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.type, .progressiveOverload)
        XCTAssertTrue(suggestion?.message.contains("3 times") ?? false)
    }

    func testSuggestion_LowReps_NoProgressiveOverload() {
        // Given: 2 sessions but only 4 reps (below threshold)
        viewModel.workouts.append(createWorkout(weight: 225, reps: 4, daysAgo: 7))
        viewModel.workouts.append(createWorkout(weight: 225, reps: 4, daysAgo: 3))

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: Consistent performance (not progressive overload for low reps)
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.type, .consistentPerformance)
    }

    // MARK: - Consistent Performance Tests

    func testSuggestion_VaryingWeights_ReturnsConsistentPerformance() {
        // Given: Sessions with different weights
        viewModel.workouts.append(createWorkout(weight: 175, reps: 8, daysAgo: 7))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 6, daysAgo: 3))

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: testExercise)

        // Then: Consistent performance message
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.type, .consistentPerformance)
        XCTAssertTrue(suggestion?.message.contains("Last:") ?? false)
    }

    // MARK: - Suggested Weight Tests

    func testSuggestion_UsesExerciseIncrement() {
        // Given: Exercise with 2.5lb increment
        var exercise = Exercise(
            name: "Dumbbell Curl",
            muscleGroup: .biceps,
            equipment: .dumbbell,
            defaultWeight: 25,
            defaultReps: 10,
            weightIncrement: 2.5
        )
        viewModel.exercises.append(exercise)

        viewModel.workouts.append(createWorkout(exerciseId: exercise.id, weight: 25, reps: 10, daysAgo: 7))
        viewModel.workouts.append(createWorkout(exerciseId: exercise.id, weight: 25, reps: 10, daysAgo: 3))

        // When: Get suggestion
        let suggestion = viewModel.getSuggestion(for: exercise)

        // Then: Suggests 27.5 (25 + 2.5)
        XCTAssertEqual(suggestion?.suggestedWeight, 27.5)
    }

    // MARK: - Helper Methods

    private func createWorkout(
        exerciseId: UUID? = nil,
        weight: Double,
        reps: Int,
        daysAgo: Int
    ) -> Workout {
        let id = exerciseId ?? testExercise.id
        let exercise = viewModel.exercises.first { $0.id == id } ?? testExercise!

        let workoutDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!

        let set = WorkoutSet(
            exerciseId: id,
            weight: weight,
            reps: reps,
            isWarmup: false,
            completedAt: workoutDate
        )

        let entry = ExerciseEntry(
            exercise: exercise,
            sets: [set],
            startedAt: workoutDate
        )

        return Workout(
            name: "",
            entries: [entry],
            startedAt: workoutDate,
            completedAt: workoutDate.addingTimeInterval(3600)
        )
    }
}
