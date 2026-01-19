//
//  ProgressCalculationTests.swift
//  Buff StuffTests
//
//  Unit tests for progressive overload calculation logic
//

import XCTest
@testable import Buff_Stuff

@MainActor
final class ProgressCalculationTests: XCTestCase {

    var viewModel: WorkoutViewModel!
    var testExercise: Exercise!

    override func setUp() async throws {
        try await super.setUp()
        viewModel = WorkoutViewModel()
        viewModel.workouts.removeAll()
        viewModel.exercises.removeAll()

        testExercise = Exercise(
            name: "Squat",
            muscleGroup: .legs,
            equipment: .barbell,
            defaultWeight: 135,
            defaultReps: 5
        )
        viewModel.exercises.append(testExercise)
    }

    override func tearDown() async throws {
        viewModel = nil
        testExercise = nil
        try await super.tearDown()
    }

    // MARK: - Progress Status Tests

    func testProgress_LessThan4Sessions_ReturnsNewExercise() {
        // Given: Only 3 sessions
        viewModel.workouts.append(createWorkout(weight: 135, reps: 5, daysAgo: 21))
        viewModel.workouts.append(createWorkout(weight: 140, reps: 5, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 145, reps: 5, daysAgo: 7))

        // When: Calculate progress
        let progress = viewModel.allExerciseProgress(in: .threeMonths)

        // Then: Status is new exercise
        let exerciseProgress = progress.first { $0.id == testExercise.id }
        XCTAssertNotNil(exerciseProgress)
        XCTAssertEqual(exerciseProgress?.status, .newExercise)
    }

    func testProgress_VolumeIncreasing_ReturnsProgressing() {
        // Given: 4 sessions with increasing volume
        // Baseline: 135×5 = 675, 140×5 = 700 → avg 687.5
        // Recent: 150×5 = 750, 155×5 = 775 → avg 762.5
        // Change: (762.5 - 687.5) / 687.5 = 10.9%
        viewModel.workouts.append(createWorkout(weight: 135, reps: 5, daysAgo: 28))
        viewModel.workouts.append(createWorkout(weight: 140, reps: 5, daysAgo: 21))
        viewModel.workouts.append(createWorkout(weight: 150, reps: 5, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 155, reps: 5, daysAgo: 7))

        // When: Calculate progress
        let progress = viewModel.allExerciseProgress(in: .threeMonths)

        // Then: Status is progressing
        let exerciseProgress = progress.first { $0.id == testExercise.id }
        XCTAssertNotNil(exerciseProgress)
        XCTAssertEqual(exerciseProgress?.status, .progressing)
        XCTAssertGreaterThan(exerciseProgress?.percentChange ?? 0, 2)
    }

    func testProgress_VolumeDecreasing_ReturnsDeclining() {
        // Given: 4 sessions with decreasing volume
        // Baseline: 185×5 = 925, 180×5 = 900 → avg 912.5
        // Recent: 165×5 = 825, 160×5 = 800 → avg 812.5
        // Change: (812.5 - 912.5) / 912.5 = -11%
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 28))
        viewModel.workouts.append(createWorkout(weight: 180, reps: 5, daysAgo: 21))
        viewModel.workouts.append(createWorkout(weight: 165, reps: 5, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 160, reps: 5, daysAgo: 7))

        // When: Calculate progress
        let progress = viewModel.allExerciseProgress(in: .threeMonths)

        // Then: Status is declining
        let exerciseProgress = progress.first { $0.id == testExercise.id }
        XCTAssertNotNil(exerciseProgress)
        XCTAssertEqual(exerciseProgress?.status, .declining)
        XCTAssertLessThan(exerciseProgress?.percentChange ?? 0, -2)
    }

    func testProgress_VolumeSteady_ReturnsPlateau() {
        // Given: 4 sessions with same volume
        // All sessions: 185×5 = 925 → 0% change
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 28))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 21))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 7))

        // When: Calculate progress
        let progress = viewModel.allExerciseProgress(in: .threeMonths)

        // Then: Status is plateau
        let exerciseProgress = progress.first { $0.id == testExercise.id }
        XCTAssertNotNil(exerciseProgress)
        XCTAssertEqual(exerciseProgress?.status, .plateau)
    }

    // MARK: - Volume Calculation Tests

    func testProgress_UsesTopSetVolume() {
        // Given: Workout with multiple sets, varying volumes
        let workoutDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let sets = [
            WorkoutSet(exerciseId: testExercise.id, weight: 135, reps: 5, isWarmup: true), // Warmup: 0
            WorkoutSet(exerciseId: testExercise.id, weight: 185, reps: 5, isWarmup: false), // 925
            WorkoutSet(exerciseId: testExercise.id, weight: 185, reps: 4, isWarmup: false), // 740
            WorkoutSet(exerciseId: testExercise.id, weight: 185, reps: 3, isWarmup: false), // 555
        ]

        let entry = ExerciseEntry(exercise: testExercise, sets: sets, startedAt: workoutDate)
        let workout = Workout(name: "", entries: [entry], startedAt: workoutDate, completedAt: workoutDate)
        viewModel.workouts.append(workout)

        // Add 3 more workouts to meet minimum
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 14))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 21))
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 28))

        // When: Get data points
        let dataPoints = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .threeMonths)

        // Then: Uses highest volume (925) not total
        let recentDataPoint = dataPoints.last
        XCTAssertEqual(recentDataPoint?.volume, 925)
    }

    func testProgress_WarmupsExcluded() {
        // Given: Workout with only warmup sets
        let workoutDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let sets = [
            WorkoutSet(exerciseId: testExercise.id, weight: 135, reps: 10, isWarmup: true),
            WorkoutSet(exerciseId: testExercise.id, weight: 155, reps: 5, isWarmup: true),
        ]

        let entry = ExerciseEntry(exercise: testExercise, sets: sets, startedAt: workoutDate)
        let workout = Workout(name: "", entries: [entry], startedAt: workoutDate, completedAt: workoutDate)
        viewModel.workouts.append(workout)

        // When: Get data points
        let dataPoints = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .threeMonths)

        // Then: No data points (warmups don't count)
        XCTAssertTrue(dataPoints.isEmpty)
    }

    // MARK: - Time Period Tests

    func testProgress_RespectsTimePeriod() {
        // Given: Workouts spanning different periods
        viewModel.workouts.append(createWorkout(weight: 185, reps: 5, daysAgo: 5))   // Within week
        viewModel.workouts.append(createWorkout(weight: 180, reps: 5, daysAgo: 10))  // Within month
        viewModel.workouts.append(createWorkout(weight: 175, reps: 5, daysAgo: 40))  // Within 3 months
        viewModel.workouts.append(createWorkout(weight: 170, reps: 5, daysAgo: 100)) // Outside 3 months

        // When: Query different periods
        let weekData = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .week)
        let monthData = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .month)
        let quarterData = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .threeMonths)
        let allData = viewModel.exerciseProgressDataPointsFull(exerciseId: testExercise.id, in: .allTime)

        // Then: Correct counts per period
        XCTAssertEqual(weekData.count, 1)
        XCTAssertEqual(monthData.count, 2)
        XCTAssertEqual(quarterData.count, 3)
        XCTAssertEqual(allData.count, 4)
    }

    // MARK: - Helper Methods

    private func createWorkout(weight: Double, reps: Int, daysAgo: Int) -> Workout {
        let workoutDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!

        let set = WorkoutSet(
            exerciseId: testExercise.id,
            weight: weight,
            reps: reps,
            isWarmup: false,
            completedAt: workoutDate
        )

        let entry = ExerciseEntry(
            exercise: testExercise,
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
