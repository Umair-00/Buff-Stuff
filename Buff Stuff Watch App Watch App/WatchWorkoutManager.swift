//
//  WatchWorkoutManager.swift
//  Buff Stuff Watch App
//
//  Manages HealthKit workout sessions on Apple Watch for active calorie tracking
//

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
class WatchWorkoutManager: NSObject {
    // MARK: - State
    private(set) var isWorkoutActive: Bool = false
    private(set) var activeCalories: Double = 0
    private(set) var heartRate: Double = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var workoutStartDate: Date?

    // MARK: - Private
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var heartRateSamples: [Double] = []
    private var elapsedTimer: Timer?

    // MARK: - Initialization
    override init() {
        super.init()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    // MARK: - Workout Session

    func startWorkout() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()

        workoutSession?.delegate = self
        workoutBuilder?.delegate = self
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutStartDate = Date()
        workoutSession?.startActivity(with: workoutStartDate!)
        try await workoutBuilder?.beginCollection(at: workoutStartDate!)

        isWorkoutActive = true
        activeCalories = 0
        heartRate = 0
        heartRateSamples = []
        elapsedTime = 0

        // Start elapsed time timer
        startElapsedTimer()

        print("[WatchWorkout] Started workout session")
    }

    func endWorkout() async throws -> WatchWorkoutData {
        guard let session = workoutSession, let builder = workoutBuilder else {
            throw WorkoutError.noActiveSession
        }

        let endDate = Date()
        session.end()
        try await builder.endCollection(at: endDate)
        try await builder.finishWorkout()

        let workoutData = WatchWorkoutData(
            activeCalories: activeCalories,
            totalCalories: activeCalories,
            averageHeartRate: heartRateSamples.isEmpty ? nil : heartRateSamples.reduce(0, +) / Double(heartRateSamples.count),
            maxHeartRate: heartRateSamples.max(),
            startDate: workoutStartDate ?? endDate,
            endDate: endDate
        )

        print("[WatchWorkout] Ended workout: \(activeCalories) cal, avg HR: \(workoutData.averageHeartRate ?? 0)")

        cleanup()
        return workoutData
    }

    func cancelWorkout() {
        print("[WatchWorkout] Cancelling workout")
        workoutSession?.end()
        cleanup()
    }

    private func cleanup() {
        stopElapsedTimer()
        workoutSession = nil
        workoutBuilder = nil
        isWorkoutActive = false
        workoutStartDate = nil
        activeCalories = 0
        heartRate = 0
        heartRateSamples = []
        elapsedTime = 0
    }

    // MARK: - Timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let startDate = self.workoutStartDate else { return }
                self.elapsedTime = Date().timeIntervalSince(startDate)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Errors

    enum WorkoutError: LocalizedError {
        case noActiveSession
        case healthKitNotAvailable

        var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No active workout session"
            case .healthKitNotAvailable:
                return "HealthKit is not available"
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            print("[WatchWorkout] State changed: \(fromState.rawValue) → \(toState.rawValue)")
            switch toState {
            case .running:
                self.isWorkoutActive = true
            case .ended, .stopped:
                self.isWorkoutActive = false
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            print("[WatchWorkout] Session failed: \(error.localizedDescription)")
            self.cleanup()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                if quantityType == HKQuantityType(.activeEnergyBurned) {
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    let calories = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    self.activeCalories = calories
                }

                if quantityType == HKQuantityType(.heartRate) {
                    let statistics = workoutBuilder.statistics(for: quantityType)
                    if let hr = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        self.heartRate = hr
                        self.heartRateSamples.append(hr)
                    }
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}
