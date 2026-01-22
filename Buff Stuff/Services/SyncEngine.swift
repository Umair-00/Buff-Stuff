//
//  SyncEngine.swift
//  Buff Stuff
//
//  Sync orchestration for CloudKit integration
//

import Foundation
import CloudKit
import Network
import Observation

@MainActor
@Observable
class SyncEngine {
    // MARK: - Singleton
    static let shared = SyncEngine()

    // MARK: - State
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?
    private(set) var lastError: String?
    private(set) var isNetworkAvailable: Bool = true

    // MARK: - Dependencies
    private let cloudKit = CloudKitManager.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.buffstuff.networkmonitor")

    // MARK: - Sync Metadata
    private var syncMetadata: SyncMetadata
    private var pendingChanges: [PendingChange] = []

    // MARK: - Debounce
    private var syncTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 30 // 30 second debounce for active workout

    // MARK: - UserDefaults Keys
    private let syncMetadataKey = "buff_stuff_sync_metadata"
    private let pendingChangesKey = "buff_stuff_pending_sync_changes"

    // MARK: - Callbacks (set by WorkoutViewModel)
    var onExercisesReceived: (([Exercise]) -> Void)?
    var onWorkoutsReceived: (([Workout]) -> Void)?
    var onExerciseDeleted: ((UUID) -> Void)?
    var onWorkoutDeleted: ((UUID) -> Void)?

    // MARK: - Initialization
    private init() {
        syncMetadata = Self.loadSyncMetadata()
        pendingChanges = Self.loadPendingChanges()
        setupNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                if path.status == .satisfied {
                    // Network restored, try to sync pending changes
                    await self?.syncPendingChanges()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public Sync Methods

    /// Full sync: push local changes, then pull remote changes
    func sync() async {
        guard cloudKit.iCloudSyncEnabled else { return }
        guard cloudKit.isAvailable else {
            syncStatus = .error
            lastError = CloudKitError.notAvailable.localizedDescription
            return
        }

        guard isNetworkAvailable else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        do {
            // Ensure zone exists
            try await cloudKit.createCustomZoneIfNeeded()

            // Push local changes first
            try await pushLocalChanges()

            // Then pull remote changes
            try await pullRemoteChanges()

            syncStatus = .idle
            lastSyncDate = Date()
            lastError = nil
            cloudKit.lastSyncDate = lastSyncDate
            saveSyncMetadata()

        } catch {
            syncStatus = .error
            lastError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }
    }

    /// Trigger sync with debounce (for active workout updates)
    func syncWithDebounce() {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            if !Task.isCancelled {
                await sync()
            }
        }
    }

    /// Force immediate sync (for app backgrounding)
    func syncImmediately() async {
        syncTask?.cancel()
        await sync()
    }

    // MARK: - Push Changes

    private func pushLocalChanges() async throws {
        // First sync any pending offline changes
        await syncPendingChanges()
    }

    /// Queue a change for sync
    func queueChange(recordId: UUID, recordType: String, changeType: PendingChange.ChangeType) {
        // Remove any existing pending change for this record
        pendingChanges.removeAll { $0.recordId == recordId }

        let change = PendingChange(
            recordId: recordId,
            recordType: recordType,
            changeType: changeType
        )
        pendingChanges.append(change)
        savePendingChanges()

        // Update sync metadata
        syncMetadata.markForUpload(recordId, recordType: recordType)
        saveSyncMetadata()
    }

    /// Queue an exercise for upload
    func queueExercise(_ exercise: Exercise, changeType: PendingChange.ChangeType = .update) {
        queueChange(recordId: exercise.id, recordType: CloudKitRecordType.exercise.rawValue, changeType: changeType)
    }

    /// Queue a workout for upload
    func queueWorkout(_ workout: Workout, changeType: PendingChange.ChangeType = .update) {
        queueChange(recordId: workout.id, recordType: CloudKitRecordType.workout.rawValue, changeType: changeType)
    }

    /// Queue a deletion
    func queueDeletion(recordId: UUID, recordType: String) {
        queueChange(recordId: recordId, recordType: recordType, changeType: .delete)
        syncMetadata.markDeleted(recordId)
        saveSyncMetadata()
    }

    /// Sync pending changes to CloudKit
    private func syncPendingChanges() async {
        guard isNetworkAvailable, !pendingChanges.isEmpty else { return }

        var successfulChanges: [UUID] = []

        for change in pendingChanges {
            do {
                switch change.changeType {
                case .delete:
                    let recordID = cloudKit.recordID(for: change.recordId, recordType: change.recordType)
                    try await cloudKit.deleteRecord(recordID: recordID)
                    successfulChanges.append(change.recordId)

                case .create, .update:
                    // The actual record data will be pushed via pushExercises/pushWorkouts
                    // This just tracks what needs syncing
                    successfulChanges.append(change.recordId)
                }

                // Mark as synced
                syncMetadata.markSynced(change.recordId, serverModifiedAt: Date())

            } catch {
                print("❌ Failed to sync change \(change.id): \(error)")
                // Update retry count
                if var pendingChange = pendingChanges.first(where: { $0.id == change.id }) {
                    pendingChange.retryCount += 1
                    pendingChange.lastError = error.localizedDescription
                }
            }
        }

        // Remove successful changes
        pendingChanges.removeAll { successfulChanges.contains($0.recordId) }
        savePendingChanges()
        saveSyncMetadata()
    }

    /// Push exercises to CloudKit
    func pushExercises(_ exercises: [Exercise]) async throws {
        guard cloudKit.iCloudSyncEnabled, isNetworkAvailable else { return }

        let zoneID = CKRecordZone.ID(zoneName: "BuffStuffZone", ownerName: CKCurrentUserDefaultName)
        let records = exercises.map { $0.toCKRecord(in: zoneID) }

        try await cloudKit.saveRecords(records)

        // Mark all as synced
        for exercise in exercises {
            syncMetadata.markSynced(exercise.id, serverModifiedAt: Date())
        }
        saveSyncMetadata()
    }

    /// Push workouts to CloudKit
    func pushWorkouts(_ workouts: [Workout]) async throws {
        guard cloudKit.iCloudSyncEnabled, isNetworkAvailable else { return }

        let zoneID = CKRecordZone.ID(zoneName: "BuffStuffZone", ownerName: CKCurrentUserDefaultName)
        let records = workouts.map { $0.toCKRecord(in: zoneID) }

        try await cloudKit.saveRecords(records)

        // Mark all as synced
        for workout in workouts {
            syncMetadata.markSynced(workout.id, serverModifiedAt: Date())
        }
        saveSyncMetadata()
    }

    // MARK: - Pull Changes

    private func pullRemoteChanges() async throws {
        let (changedRecords, deletedIDs, newToken) = try await cloudKit.fetchChanges()

        // Process changed records
        var exercises: [Exercise] = []
        var workouts: [Workout] = []

        for record in changedRecords {
            switch record.recordType {
            case CloudKitRecordType.exercise.rawValue:
                if let exercise = Exercise.from(record: record) {
                    if exercise.isDeleted {
                        onExerciseDeleted?(exercise.id)
                    } else {
                        exercises.append(exercise)
                    }
                }
            case CloudKitRecordType.workout.rawValue:
                if let workout = Workout.from(record: record) {
                    if workout.isDeleted {
                        onWorkoutDeleted?(workout.id)
                    } else {
                        workouts.append(workout)
                    }
                }
            default:
                break
            }
        }

        // Notify callbacks
        if !exercises.isEmpty {
            onExercisesReceived?(exercises)
        }
        if !workouts.isEmpty {
            onWorkoutsReceived?(workouts)
        }

        // Process deletions
        for recordID in deletedIDs {
            if let uuid = UUID(uuidString: recordID.recordName) {
                // We don't know the type, so try both
                onExerciseDeleted?(uuid)
                onWorkoutDeleted?(uuid)
            }
        }

        // Save new token
        if let newToken = newToken {
            cloudKit.saveServerChangeToken(newToken)
        }
    }

    // MARK: - Initial Migration

    /// Upload all local data to CloudKit (first-time sync)
    func performInitialMigration(exercises: [Exercise], workouts: [Workout]) async throws {
        guard cloudKit.iCloudSyncEnabled else { return }
        guard !cloudKit.hasMigrated else { return }

        syncStatus = .syncing

        do {
            try await cloudKit.createCustomZoneIfNeeded()
            try await pushExercises(exercises)
            try await pushWorkouts(workouts)

            cloudKit.hasMigrated = true
            syncStatus = .idle
            print("✅ Initial migration complete: \(exercises.count) exercises, \(workouts.count) workouts")

        } catch {
            syncStatus = .error
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Conflict Resolution

    /// Resolve conflict between local and server versions
    func resolveConflict<T: Syncable>(local: T, server: T) -> T {
        let conflict = SyncConflict(
            recordId: local.id,
            recordType: String(describing: T.self),
            localModifiedAt: local.modifiedAt,
            serverModifiedAt: server.modifiedAt
        )

        switch conflict.resolve() {
        case .useLocal:
            return local
        case .useServer, .merge:
            return server
        }
    }

    // MARK: - Persistence

    private static func loadSyncMetadata() -> SyncMetadata {
        guard let data = UserDefaults.standard.data(forKey: "buff_stuff_sync_metadata"),
              let metadata = try? JSONDecoder().decode(SyncMetadata.self, from: data) else {
            return SyncMetadata()
        }
        return metadata
    }

    private func saveSyncMetadata() {
        if let data = try? JSONEncoder().encode(syncMetadata) {
            UserDefaults.standard.set(data, forKey: syncMetadataKey)
        }
    }

    private static func loadPendingChanges() -> [PendingChange] {
        guard let data = UserDefaults.standard.data(forKey: "buff_stuff_pending_sync_changes"),
              let changes = try? JSONDecoder().decode([PendingChange].self, from: data) else {
            return []
        }
        return changes
    }

    private func savePendingChanges() {
        if let data = try? JSONEncoder().encode(pendingChanges) {
            UserDefaults.standard.set(data, forKey: pendingChangesKey)
        }
    }

    // MARK: - Setup

    /// Setup CloudKit subscription for push notifications
    func setupSubscription() async {
        guard cloudKit.iCloudSyncEnabled else { return }
        do {
            try await cloudKit.setupSubscription()
        } catch {
            print("❌ Failed to setup subscription: \(error)")
        }
    }

    // MARK: - Status Helpers

    var statusMessage: String {
        switch syncStatus {
        case .idle:
            if let date = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .error:
            return lastError ?? "Sync error"
        case .offline:
            return "Offline - changes will sync when online"
        }
    }

    var hasPendingChanges: Bool {
        !pendingChanges.isEmpty
    }

    var pendingChangeCount: Int {
        pendingChanges.count
    }
}
