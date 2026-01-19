//
//  HealthKitManager.swift
//  Buff Stuff
//
//  HealthKit integration for syncing workouts to Apple Health
//

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
class HealthKitManager {
    // MARK: - Singleton
    static let shared = HealthKitManager()

    // MARK: - State
    private(set) var isAvailable: Bool = false
    private(set) var isAuthorized: Bool = false
    var isHealthKitSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHealthKitSyncEnabled, forKey: healthKitEnabledKey)
        }
    }

    // MARK: - Private
    private let healthStore = HKHealthStore()
    private let healthKitEnabledKey = "buff_stuff_healthkit_enabled"
    private let syncedWorkoutIdsKey = "buff_stuff_synced_workout_ids"

    // MARK: - Live Workout Session
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKWorkoutBuilder?

    // Types we want to write
    private let workoutType = HKQuantityType.workoutType()

    // Types we want to read
    private let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private let basalEnergyType = HKQuantityType(.basalEnergyBurned)
    private let heartRateType = HKQuantityType(.heartRate)

    // MARK: - Initialization
    private init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        isHealthKitSyncEnabled = UserDefaults.standard.bool(forKey: healthKitEnabledKey)

        // Check current authorization status
        if isAvailable {
            Task {
                await checkAuthorizationStatus()
            }
        }
    }

    // MARK: - Authorization

    /// Check current authorization status without prompting
    private func checkAuthorizationStatus() async {
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = status == .sharingAuthorized
    }

    /// Request authorization to write workouts
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        let typesToWrite: Set<HKSampleType> = [workoutType]
        let typesToRead: Set<HKObjectType> = [activeEnergyType, basalEnergyType, heartRateType]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        // Update authorization status after request
        await checkAuthorizationStatus()
    }

    // MARK: - Live Workout Session

    /// Start a live workout session (triggers watch tracking if paired)
    func startWorkoutSession() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()

        workoutSession?.startActivity(with: Date())
        try await workoutBuilder?.beginCollection(at: Date())
    }

    /// End the live workout session
    func endWorkoutSession() async throws {
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        session.end()
        try await builder.endCollection(at: Date())
        try await builder.finishWorkout()

        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Calorie Query

    /// Query active calories burned during a time window (from Apple Watch data)
    func getActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        let predicate = HKSamplePredicate.quantitySample(
            type: activeEnergyType,
            predicate: HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum
        )

        let result = try await descriptor.result(for: healthStore)
        let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
        return calories
    }

    /// Query basal (resting) calories burned during a time window
    func getBasalCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        let predicate = HKSamplePredicate.quantitySample(
            type: basalEnergyType,
            predicate: HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: predicate,
            options: .cumulativeSum
        )

        let result = try await descriptor.result(for: healthStore)
        let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
        return calories
    }

    /// Query heart rate samples during a time window (from Apple Watch)
    func getHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let predicate = HKSamplePredicate.quantitySample(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )

        let samples = try await descriptor.result(for: healthStore)
        return samples
    }

    // MARK: - Workout Sync

    /// Save a completed workout to HealthKit
    func saveWorkout(_ workout: Workout) async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        guard let completedAt = workout.completedAt else {
            throw HealthKitError.workoutNotCompleted
        }

        // Check if already synced
        guard !isWorkoutSynced(workout.id) else {
            return
        }

        // Query data from Apple Watch during workout window
        let activeCalories = try? await getActiveCalories(
            from: workout.startedAt,
            to: completedAt
        )
        let basalCalories = try? await getBasalCalories(
            from: workout.startedAt,
            to: completedAt
        )
        let heartRateSamples = try? await getHeartRateSamples(
            from: workout.startedAt,
            to: completedAt
        )

        // Build workout using HKWorkoutBuilder (modern iOS 17+ approach)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )

        try await builder.beginCollection(at: workout.startedAt)

        // Add calorie samples to workout
        var samples: [HKQuantitySample] = []

        // Active calories (shows as "Active Calories" in Fitness app)
        if let activeCalories = activeCalories, activeCalories > 0 {
            let activeQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeCalories)
            let activeSample = HKQuantitySample(
                type: activeEnergyType,
                quantity: activeQuantity,
                start: workout.startedAt,
                end: completedAt
            )
            samples.append(activeSample)
        }

        // Basal calories (combined with active = "Total Calories" in Fitness app)
        if let basalCalories = basalCalories, basalCalories > 0 {
            let basalQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: basalCalories)
            let basalSample = HKQuantitySample(
                type: basalEnergyType,
                quantity: basalQuantity,
                start: workout.startedAt,
                end: completedAt
            )
            samples.append(basalSample)
        }

        // Heart rate samples (shows as "Avg. Heart Rate" in Fitness app)
        if let heartRateSamples = heartRateSamples {
            samples.append(contentsOf: heartRateSamples)
        }

        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        try await builder.endCollection(at: completedAt)

        // Add metadata and finish
        try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Buff Stuff"])
        try await builder.finishWorkout()

        // Mark as synced
        markWorkoutSynced(workout.id)
    }

    // MARK: - Sync Tracking

    /// Check if a workout has already been synced
    func isWorkoutSynced(_ id: UUID) -> Bool {
        let syncedIds = getSyncedWorkoutIds()
        return syncedIds.contains(id.uuidString)
    }

    /// Mark a workout as synced
    private func markWorkoutSynced(_ id: UUID) {
        var syncedIds = getSyncedWorkoutIds()
        syncedIds.insert(id.uuidString)
        saveSyncedWorkoutIds(syncedIds)
    }

    private func getSyncedWorkoutIds() -> Set<String> {
        guard let array = UserDefaults.standard.array(forKey: syncedWorkoutIdsKey) as? [String] else {
            return []
        }
        return Set(array)
    }

    private func saveSyncedWorkoutIds(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: syncedWorkoutIdsKey)
    }
}

// MARK: - Errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case workoutNotCompleted

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit authorization not granted"
        case .workoutNotCompleted:
            return "Cannot sync an incomplete workout"
        }
    }
}
