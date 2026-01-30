import Foundation
import SwiftUI
import Observation

// MARK: - Data Backup Structure
struct DataBackup: Codable {
    let schemaVersion: Int
    let exportDate: Date
    let exercises: [Exercise]
    let workouts: [Workout]
}

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

    /// Minimum sessions required to calculate progress status for this time period
    var minimumSessionsForProgress: Int {
        switch self {
        case .week: return 2        // 7D: compare 1 vs 1
        case .month: return 3       // 30D: compare 1 vs avg of 2
        case .threeMonths: return 4 // 90D: compare avg 2 vs avg 2
        case .allTime: return 4     // ALL: compare avg 2 vs avg 2
        }
    }
}

// MARK: - Progress Status
enum ProgressStatus {
    case progressing  // ↑ >2% volume increase
    case plateau      // → -2% to +2% change
    case declining    // ↓ >2% volume decrease
    case newExercise  // ★ Not enough data points for time period

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

// MARK: - Workout Suggestion
struct WorkoutSuggestion {
    enum SuggestionType {
        case progressiveOverload  // Ready to increase weight
        case consistentPerformance  // Doing well, keep it up
        case newExercise  // Not enough data yet
    }

    let type: SuggestionType
    let message: String
    let suggestedWeight: Double?

    var icon: String {
        switch type {
        case .progressiveOverload: return "arrow.up.circle.fill"
        case .consistentPerformance: return "checkmark.circle.fill"
        case .newExercise: return "star.circle.fill"
        }
    }
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
    private let schemaVersionKey = "buff_stuff_schema_version"
    private let currentSchemaVersion = 1

    // MARK: - Sync Engine
    private let syncEngine = SyncEngine.shared

    // MARK: - Watch Connectivity
    private let watchManager = WatchConnectivityManager.shared

    // MARK: - Initialization
    init() {
        loadData()
        setupSyncCallbacks()
        recoverExercisesFromWorkoutHistory()

        // If no exercises, add samples
        if exercises.isEmpty {
            exercises = Exercise.samples
            saveExercises()
        }
    }

    /// Recover exercises from workout history that may be missing from exercises array
    private func recoverExercisesFromWorkoutHistory() {
        let existingIds = Set(exercises.map { $0.id })
        var recoveredExercises: [Exercise] = []

        for workout in workouts {
            for entry in workout.entries {
                if !existingIds.contains(entry.exercise.id) &&
                   !recoveredExercises.contains(where: { $0.id == entry.exercise.id }) {
                    recoveredExercises.append(entry.exercise)
                }
            }
        }

        if !recoveredExercises.isEmpty {
            exercises.append(contentsOf: recoveredExercises)
            saveExercises()
            print("📦 Recovered \(recoveredExercises.count) exercises from workout history")
        }
    }

    // MARK: - Sync Setup

    private func setupSyncCallbacks() {
        syncEngine.onExercisesReceived = { [weak self] remoteExercises in
            self?.applyRemoteExercises(remoteExercises)
        }
        syncEngine.onWorkoutsReceived = { [weak self] remoteWorkouts in
            self?.applyRemoteWorkouts(remoteWorkouts)
        }
        syncEngine.onExerciseDeleted = { [weak self] id in
            self?.handleRemoteExerciseDeletion(id)
        }
        syncEngine.onWorkoutDeleted = { [weak self] id in
            self?.handleRemoteWorkoutDeletion(id)
        }
    }

    /// Trigger sync (called from ContentView on launch/foreground)
    func triggerSync() async {
        await syncEngine.sync()
    }

    /// Perform initial migration if needed
    func performInitialMigrationIfNeeded() async {
        guard CloudKitManager.shared.iCloudSyncEnabled else { return }
        guard !CloudKitManager.shared.hasMigrated else { return }

        try? await syncEngine.performInitialMigration(exercises: exercises, workouts: workouts)
    }

    // MARK: - Remote Change Handlers

    private func applyRemoteExercises(_ remoteExercises: [Exercise]) {
        for remote in remoteExercises {
            if let index = exercises.firstIndex(where: { $0.id == remote.id }) {
                // Conflict resolution: use newer version
                let local = exercises[index]
                let resolved = syncEngine.resolveConflict(local: local, server: remote)
                exercises[index] = resolved
            } else {
                // New exercise from remote
                exercises.append(remote)
            }
        }
        saveExercises(sync: false) // Don't re-sync changes we just received
    }

    private func applyRemoteWorkouts(_ remoteWorkouts: [Workout]) {
        for remote in remoteWorkouts {
            if let index = workouts.firstIndex(where: { $0.id == remote.id }) {
                // Conflict resolution: use newer version
                // But never overwrite active workout with remote
                if activeWorkout?.id == remote.id {
                    continue // Local active workout takes precedence
                }
                let local = workouts[index]
                let resolved = syncEngine.resolveConflict(local: local, server: remote)
                workouts[index] = resolved
            } else {
                // New workout from remote
                workouts.append(remote)
            }
        }
        workouts.sort { $0.startedAt > $1.startedAt }
        saveWorkouts(sync: false) // Don't re-sync changes we just received
    }

    private func handleRemoteExerciseDeletion(_ id: UUID) {
        exercises.removeAll { $0.id == id }
        saveExercises(sync: false)
    }

    private func handleRemoteWorkoutDeletion(_ id: UUID) {
        workouts.removeAll { $0.id == id }
        saveWorkouts(sync: false)
    }

    // MARK: - Data Persistence
    private func loadData() {
        // Save schema version for future migrations
        UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)

        // Load exercises with error handling
        if let data = UserDefaults.standard.data(forKey: exercisesKey) {
            do {
                exercises = try JSONDecoder().decode([Exercise].self, from: data)
            } catch {
                print("⚠️ Failed to decode exercises: \(error.localizedDescription)")
                backupCorruptedData(data, key: exercisesKey)
            }
        }

        // Load workouts with error handling
        if let data = UserDefaults.standard.data(forKey: workoutsKey) {
            do {
                workouts = try JSONDecoder().decode([Workout].self, from: data)
                    .sorted { $0.startedAt > $1.startedAt }
            } catch {
                print("⚠️ Failed to decode workouts: \(error.localizedDescription)")
                backupCorruptedData(data, key: workoutsKey)
            }
        }

        // Load active workout with error handling
        if let data = UserDefaults.standard.data(forKey: activeWorkoutKey) {
            do {
                activeWorkout = try JSONDecoder().decode(Workout.self, from: data)
            } catch {
                print("⚠️ Failed to decode active workout: \(error.localizedDescription)")
                backupCorruptedData(data, key: activeWorkoutKey)
                // Clear corrupted active workout so user can start fresh
                UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
            }
        }
    }

    /// Backup corrupted data for potential recovery
    private func backupCorruptedData(_ data: Data, key: String) {
        let backupKey = "\(key)_backup_\(Int(Date().timeIntervalSince1970))"
        UserDefaults.standard.set(data, forKey: backupKey)
        print("📦 Backed up corrupted data to: \(backupKey)")
    }

    private func saveExercises(sync: Bool = true) {
        if let encoded = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: exercisesKey)
        }

        // Queue all exercises for sync if enabled
        if sync && CloudKitManager.shared.iCloudSyncEnabled {
            Task {
                try? await syncEngine.pushExercises(exercises)
            }
        }
    }

    private func saveWorkouts(sync: Bool = true) {
        if let encoded = try? JSONEncoder().encode(workouts) {
            UserDefaults.standard.set(encoded, forKey: workoutsKey)
        }

        // Queue completed workouts for sync if enabled
        if sync && CloudKitManager.shared.iCloudSyncEnabled {
            let completedWorkouts = workouts.filter { $0.completedAt != nil }
            Task {
                try? await syncEngine.pushWorkouts(completedWorkouts)
            }
        }
    }

    private func saveActiveWorkout(sync: Bool = true) {
        if let workout = activeWorkout,
           let encoded = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(encoded, forKey: activeWorkoutKey)

            // Debounced sync for active workout
            if sync && CloudKitManager.shared.iCloudSyncEnabled {
                syncEngine.syncWithDebounce()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: activeWorkoutKey)
        }
    }

    // MARK: - Export / Import

    /// Export all data to JSON
    func exportData() throws -> Data {
        let backup = DataBackup(
            schemaVersion: currentSchemaVersion,
            exportDate: Date(),
            exercises: exercises,
            workouts: workouts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Import data from JSON backup
    func importData(from data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DataBackup.self, from: data)

        // Replace current data with imported data
        exercises = backup.exercises
        workouts = backup.workouts.sorted { $0.startedAt > $1.startedAt }

        // Save to UserDefaults
        saveExercises()
        saveWorkouts()

        print("✅ Imported \(backup.exercises.count) exercises and \(backup.workouts.count) workouts")
    }

    // MARK: - Workout Management
    func startWorkout() {
        activeWorkout = Workout()
        saveActiveWorkout()

        // Start HealthKit session if enabled
        if HealthKitManager.shared.isHealthKitSyncEnabled {
            Task {
                try? await HealthKitManager.shared.startWorkoutSession()
            }
        }

        // Start watch workout for active calorie tracking
        if watchManager.isReachable {
            watchManager.startWatchWorkout()
        }

        triggerHaptic(.medium)
    }

    func finishWorkout() {
        guard var workout = activeWorkout else { return }
        workout.completedAt = Date()
        workout.modifiedAt = Date()
        workouts.insert(workout, at: 0)
        activeWorkout = nil
        saveWorkouts()
        saveActiveWorkout()

        // End HealthKit session and sync workout
        Task {
            try? await HealthKitManager.shared.endWorkoutSession()
            await saveWorkoutToHealthKit(workout)
        }

        // End watch workout session
        if watchManager.watchWorkoutActive {
            watchManager.endWatchWorkout()
        }

        triggerHaptic(.success)
    }

    private func saveWorkoutToHealthKit(_ workout: Workout) async {
        let healthKit = HealthKitManager.shared
        guard healthKit.isHealthKitSyncEnabled, healthKit.isAuthorized else { return }
        try? await healthKit.saveWorkout(workout)
    }

    func cancelWorkout() {
        activeWorkout = nil
        saveActiveWorkout()

        // End HealthKit session if discarding
        Task {
            try? await HealthKitManager.shared.endWorkoutSession()
        }

        // Cancel watch workout session
        if watchManager.watchWorkoutActive {
            watchManager.cancelWatchWorkout()
        }
    }

    func deleteWorkout(_ workout: Workout) {
        // Soft delete for sync
        if CloudKitManager.shared.iCloudSyncEnabled {
            if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                workouts[index].isDeleted = true
                workouts[index].modifiedAt = Date()
                syncEngine.queueDeletion(recordId: workout.id, recordType: CloudKitRecordType.workout.rawValue)
            }
        }
        workouts.removeAll { $0.id == workout.id }
        saveWorkouts()
        triggerHaptic(.light)
    }

    // MARK: - Exercise Management
    func addExercise(_ exercise: Exercise) {
        var newExercise = exercise
        newExercise.modifiedAt = Date()
        exercises.append(newExercise)
        saveExercises()
        triggerHaptic(.light)
    }

    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            var updated = exercise
            updated.modifiedAt = Date()
            exercises[index] = updated
            saveExercises()
        }
    }

    func deleteExercise(_ exercise: Exercise) {
        // Soft delete for sync
        if CloudKitManager.shared.iCloudSyncEnabled {
            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                exercises[index].isDeleted = true
                exercises[index].modifiedAt = Date()
                syncEngine.queueDeletion(recordId: exercise.id, recordType: CloudKitRecordType.exercise.rawValue)
            }
        }
        exercises.removeAll { $0.id == exercise.id }
        saveExercises()
    }

    func toggleFavorite(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index].isFavorite.toggle()
            exercises[index].modifiedAt = Date()
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
    /// Uses top set (highest volume working set) for volume/reps, and tracks heaviest weight separately
    func exerciseProgressDataPointsFull(exerciseId: UUID, in period: ProgressTimePeriod) -> [(date: Date, weight: Double, reps: Int, volume: Double, topWeight: Double)] {
        workouts(in: period)
            .compactMap { workout -> (date: Date, weight: Double, reps: Int, volume: Double, topWeight: Double)? in
                guard let entry = workout.entries.first(where: { $0.exercise.id == exerciseId }) else {
                    return nil
                }
                // Find top set by volume (weight × reps)
                guard let topVolumeSet = entry.workingSets.max(by: { $0.volume < $1.volume }),
                      topVolumeSet.volume > 0 else {
                    return nil
                }
                // Find heaviest weight lifted (regardless of reps)
                let topWeight = entry.workingSets.map { $0.weight }.max() ?? topVolumeSet.weight
                return (date: workout.startedAt, weight: topVolumeSet.weight, reps: topVolumeSet.reps, volume: topVolumeSet.volume, topWeight: topWeight)
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

            // Use adaptive threshold based on time period
            let minSessions = period.minimumSessionsForProgress
            if dataPoints.count < minSessions {
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

            // Split data based on time period's minimum sessions
            let sortedByDate = dataPoints.sorted { $0.date > $1.date }

            let recentAvg: Double
            let baselineAvg: Double

            switch minSessions {
            case 2:
                // 7D: Compare 1 vs 1
                recentAvg = sortedByDate[0].volume
                baselineAvg = sortedByDate[1].volume
            case 3:
                // 30D: Compare 1 vs average of 2
                recentAvg = sortedByDate[0].volume
                let baseline = Array(sortedByDate.dropFirst().prefix(2))
                baselineAvg = baseline.map { $0.volume }.reduce(0, +) / Double(baseline.count)
            default:
                // 90D/ALL: Compare average of 2 vs average of 2 (original behavior)
                let recentSessions = Array(sortedByDate.prefix(2))
                let olderSessions = Array(sortedByDate.dropFirst(2).prefix(2))
                recentAvg = recentSessions.map { $0.volume }.reduce(0, +) / Double(recentSessions.count)
                baselineAvg = olderSessions.map { $0.volume }.reduce(0, +) / Double(olderSessions.count)
            }

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

    // MARK: - Smart Suggestions

    /// Generate a workout suggestion for an exercise based on history
    func getSuggestion(for exercise: Exercise) -> WorkoutSuggestion? {
        // Get recent workout data for this exercise (last 90 days)
        let dataPoints = exerciseProgressDataPointsFull(exerciseId: exercise.id, in: .threeMonths)

        // Need at least 2 data points to make a suggestion
        guard dataPoints.count >= 2 else {
            if dataPoints.isEmpty {
                return nil  // No history at all
            }
            return WorkoutSuggestion(
                type: .newExercise,
                message: "Keep logging to unlock suggestions",
                suggestedWeight: nil
            )
        }

        // Analyze recent performance
        let sortedByDate = dataPoints.sorted { $0.date > $1.date }
        let recentSets = Array(sortedByDate.prefix(4))  // Last 4 sessions

        // Check if user has been consistent at a weight×reps combo
        let mostRecentWeight = recentSets[0].weight
        let mostRecentReps = recentSets[0].reps

        // Count how many times they've hit this or higher reps at this weight
        let consistentCount = recentSets.filter {
            $0.weight == mostRecentWeight && $0.reps >= mostRecentReps
        }.count

        // If they've hit the same weight for target reps 2+ times, suggest increase
        if consistentCount >= 2 && mostRecentReps >= 5 {
            let suggestedWeight = mostRecentWeight + exercise.weightIncrement
            let formattedCurrent = formatWeight(mostRecentWeight)
            let formattedSuggested = formatWeight(suggestedWeight)

            return WorkoutSuggestion(
                type: .progressiveOverload,
                message: "You've hit \(formattedCurrent)×\(mostRecentReps) \(consistentCount) times — try \(formattedSuggested)?",
                suggestedWeight: suggestedWeight
            )
        }

        // Otherwise, show encouraging message
        let formattedWeight = formatWeight(mostRecentWeight)
        return WorkoutSuggestion(
            type: .consistentPerformance,
            message: "Last: \(formattedWeight) × \(mostRecentReps) — keep pushing",
            suggestedWeight: nil
        )
    }

    /// Format weight for display (no decimals if whole number)
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
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
