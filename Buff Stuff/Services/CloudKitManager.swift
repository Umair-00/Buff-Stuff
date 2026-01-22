//
//  CloudKitManager.swift
//  Buff Stuff
//
//  CloudKit integration for iCloud sync
//

import Foundation
import CloudKit
import Observation

@MainActor
@Observable
class CloudKitManager {
    // MARK: - Singleton
    static let shared = CloudKitManager()

    // MARK: - State
    private(set) var isAvailable: Bool = false
    private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    var iCloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: cloudKitEnabledKey)
        }
    }

    // MARK: - Private
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneName = "BuffStuffZone"
    private let customZoneID: CKRecordZone.ID

    // MARK: - UserDefaults Keys
    private let cloudKitEnabledKey = "buff_stuff_cloudkit_enabled"
    private let cloudKitMigratedKey = "buff_stuff_cloudkit_migrated"
    private let lastSyncDateKey = "buff_stuff_last_sync_date"
    private let serverChangeTokenKey = "buff_stuff_server_change_token"

    // MARK: - Initialization
    private init() {
        // Use default container from entitlements
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        customZoneID = CKRecordZone.ID(zoneName: "BuffStuffZone", ownerName: CKCurrentUserDefaultName)
        iCloudSyncEnabled = UserDefaults.standard.bool(forKey: cloudKitEnabledKey)

        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Account Status

    /// Check if user is signed into iCloud
    func checkAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
            isAvailable = accountStatus == .available
        } catch {
            print("❌ CloudKit account status error: \(error.localizedDescription)")
            isAvailable = false
        }
    }

    // MARK: - Zone Management

    /// Create custom zone if it doesn't exist
    func createCustomZoneIfNeeded() async throws {
        let zone = CKRecordZone(zoneID: customZoneID)

        do {
            _ = try await privateDatabase.save(zone)
            print("✅ CloudKit zone created: \(zoneName)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
            print("✅ CloudKit zone already exists: \(zoneName)")
        } catch {
            print("❌ CloudKit zone creation failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - CRUD Operations

    /// Save a single record
    func saveRecord(_ record: CKRecord) async throws {
        do {
            _ = try await privateDatabase.save(record)
            print("✅ Saved record: \(record.recordID.recordName)")
        } catch {
            print("❌ Save failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Save multiple records
    func saveRecords(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.isAtomic = false // Allow partial success

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("✅ Saved \(records.count) records")
                    continuation.resume()
                case .failure(let error):
                    print("❌ Batch save failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    /// Fetch a single record by ID
    func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await privateDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            print("❌ Fetch failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetch all records of a type
    func fetchRecords(recordType: String, predicate: NSPredicate? = nil) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate ?? NSPredicate(value: true))

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let (records, nextCursor) = try await privateDatabase.records(
                matching: query,
                inZoneWith: customZoneID,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )

            allRecords.append(contentsOf: records.compactMap { _, result in
                try? result.get()
            })
            cursor = nextCursor
        } while cursor != nil

        print("✅ Fetched \(allRecords.count) \(recordType) records")
        return allRecords
    }

    /// Delete a record by ID
    func deleteRecord(recordID: CKRecord.ID) async throws {
        do {
            try await privateDatabase.deleteRecord(withID: recordID)
            print("✅ Deleted record: \(recordID.recordName)")
        } catch {
            print("❌ Delete failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Change Tracking

    /// Fetch changes since last sync token
    func fetchChanges() async throws -> (changed: [CKRecord], deletedIDs: [CKRecord.ID], newToken: CKServerChangeToken?) {
        let token = loadServerChangeToken()

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = token

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZoneID], configurationsByRecordZoneID: [customZoneID: configuration])

        operation.recordWasChangedBlock = { _, result in
            if case .success(let record) = result {
                changedRecords.append(record)
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            newToken = token
        }

        operation.recordZoneFetchResultBlock = { _, result in
            if case .success(let (serverToken, _, _)) = result {
                newToken = serverToken
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    print("✅ Fetched \(changedRecords.count) changes, \(deletedRecordIDs.count) deletions")
                    continuation.resume(returning: (changedRecords, deletedRecordIDs, newToken))
                case .failure(let error):
                    print("❌ Fetch changes failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    // MARK: - Token Persistence

    func saveServerChangeToken(_ token: CKServerChangeToken?) {
        guard let token = token else {
            UserDefaults.standard.removeObject(forKey: serverChangeTokenKey)
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: serverChangeTokenKey)
        } catch {
            print("❌ Failed to save change token: \(error)")
        }
    }

    func loadServerChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: serverChangeTokenKey) else {
            return nil
        }

        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        } catch {
            print("❌ Failed to load change token: \(error)")
            return nil
        }
    }

    // MARK: - Subscriptions

    /// Setup push notification subscription for changes
    func setupSubscription() async throws {
        let subscriptionID = "buff-stuff-changes"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            print("✅ Subscription already exists")
            return
        } catch let error as CKError where error.code == .unknownItem {
            // Subscription doesn't exist, create it
        }

        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // Silent push
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(subscription)
            print("✅ Created CloudKit subscription")
        } catch {
            print("❌ Subscription setup failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Helpers

    /// Get record ID for a UUID in the custom zone
    func recordID(for uuid: UUID, recordType: String) -> CKRecord.ID {
        CKRecord.ID(recordName: uuid.uuidString, zoneID: customZoneID)
    }

    /// Create a new record in the custom zone
    func newRecord(recordType: String, recordID: CKRecord.ID? = nil) -> CKRecord {
        if let recordID = recordID {
            return CKRecord(recordType: recordType, recordID: recordID)
        }
        return CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: customZoneID))
    }

    /// Check if initial migration has been done
    var hasMigrated: Bool {
        get { UserDefaults.standard.bool(forKey: cloudKitMigratedKey) }
        set { UserDefaults.standard.set(newValue, forKey: cloudKitMigratedKey) }
    }

    /// Last sync date
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncDateKey) }
    }
}

// MARK: - Errors
enum CloudKitError: LocalizedError {
    case notAvailable
    case notAuthenticated
    case quotaExceeded
    case networkUnavailable
    case serverError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available on this device"
        case .notAuthenticated:
            return "Please sign in to your iCloud account in Settings"
        case .quotaExceeded:
            return "iCloud storage is full. Free up space to continue syncing."
        case .networkUnavailable:
            return "No network connection. Changes will sync when you're back online."
        case .serverError(let error):
            return "Server error: \(error.localizedDescription)"
        }
    }
}
