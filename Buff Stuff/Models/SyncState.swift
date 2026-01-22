//
//  SyncState.swift
//  Buff Stuff
//
//  Sync metadata tracking for CloudKit integration
//

import Foundation
import CloudKit

// MARK: - Sync Status
enum SyncStatus: String, Codable {
    case idle
    case syncing
    case error
    case offline
}

// MARK: - Sync State (per-record tracking)
struct SyncState: Codable, Equatable {
    let recordId: UUID
    let recordType: String
    var lastSyncedAt: Date?
    var localModifiedAt: Date
    var serverModifiedAt: Date?
    var needsUpload: Bool
    var isDeleted: Bool

    init(
        recordId: UUID,
        recordType: String,
        lastSyncedAt: Date? = nil,
        localModifiedAt: Date = Date(),
        serverModifiedAt: Date? = nil,
        needsUpload: Bool = true,
        isDeleted: Bool = false
    ) {
        self.recordId = recordId
        self.recordType = recordType
        self.lastSyncedAt = lastSyncedAt
        self.localModifiedAt = localModifiedAt
        self.serverModifiedAt = serverModifiedAt
        self.needsUpload = needsUpload
        self.isDeleted = isDeleted
    }
}

// MARK: - Sync Metadata (global sync state)
struct SyncMetadata: Codable {
    var lastSyncDate: Date?
    var lastSuccessfulSync: Date?
    var syncStates: [UUID: SyncState]
    var serverChangeTokenData: Data?

    init(
        lastSyncDate: Date? = nil,
        lastSuccessfulSync: Date? = nil,
        syncStates: [UUID: SyncState] = [:],
        serverChangeTokenData: Data? = nil
    ) {
        self.lastSyncDate = lastSyncDate
        self.lastSuccessfulSync = lastSuccessfulSync
        self.syncStates = syncStates
        self.serverChangeTokenData = serverChangeTokenData
    }

    // MARK: - State Management

    mutating func markForUpload(_ id: UUID, recordType: String) {
        if var state = syncStates[id] {
            state.needsUpload = true
            state.localModifiedAt = Date()
            syncStates[id] = state
        } else {
            syncStates[id] = SyncState(recordId: id, recordType: recordType)
        }
    }

    mutating func markSynced(_ id: UUID, serverModifiedAt: Date) {
        if var state = syncStates[id] {
            state.needsUpload = false
            state.lastSyncedAt = Date()
            state.serverModifiedAt = serverModifiedAt
            syncStates[id] = state
        }
    }

    mutating func markDeleted(_ id: UUID) {
        if var state = syncStates[id] {
            state.isDeleted = true
            state.needsUpload = true
            state.localModifiedAt = Date()
            syncStates[id] = state
        }
    }

    func recordsNeedingUpload() -> [SyncState] {
        syncStates.values.filter { $0.needsUpload }
    }

    func pendingDeletions() -> [SyncState] {
        syncStates.values.filter { $0.isDeleted && $0.needsUpload }
    }
}

// MARK: - Pending Change (offline queue)
struct PendingChange: Codable, Identifiable {
    let id: UUID
    let recordId: UUID
    let recordType: String
    let changeType: ChangeType
    let timestamp: Date
    var retryCount: Int
    var lastError: String?

    enum ChangeType: String, Codable {
        case create
        case update
        case delete
    }

    init(
        id: UUID = UUID(),
        recordId: UUID,
        recordType: String,
        changeType: ChangeType,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.recordId = recordId
        self.recordType = recordType
        self.changeType = changeType
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

// MARK: - Conflict Resolution
enum ConflictResolution {
    case useLocal
    case useServer
    case merge
}

struct SyncConflict {
    let recordId: UUID
    let recordType: String
    let localModifiedAt: Date
    let serverModifiedAt: Date

    /// Last-writer-wins conflict resolution
    func resolve() -> ConflictResolution {
        if localModifiedAt > serverModifiedAt {
            return .useLocal
        } else {
            return .useServer
        }
    }
}

// MARK: - CloudKit Record Types
enum CloudKitRecordType: String {
    case exercise = "Exercise"
    case workout = "Workout"
}
