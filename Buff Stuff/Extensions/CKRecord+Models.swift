//
//  CKRecord+Models.swift
//  Buff Stuff
//
//  CloudKit record conversion for sync
//

import Foundation
import CloudKit

// MARK: - Syncable Protocol
protocol Syncable: Identifiable where ID == UUID {
    nonisolated var id: UUID { get }
    var modifiedAt: Date { get set }
    var isDeleted: Bool { get set }

    func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord
    static func from(record: CKRecord) -> Self?
}

// MARK: - Exercise CloudKit Extension
extension Exercise: Syncable {
    func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: CloudKitRecordType.exercise.rawValue, recordID: recordID)

        record["name"] = name as CKRecordValue
        record["muscleGroup"] = muscleGroup.rawValue as CKRecordValue
        record["equipment"] = equipment.rawValue as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["isFavorite"] = (isFavorite ? 1 : 0) as CKRecordValue
        record["isDeleted"] = (isDeleted ? 1 : 0) as CKRecordValue
        record["defaultWeight"] = defaultWeight as CKRecordValue
        record["defaultReps"] = defaultReps as CKRecordValue
        record["weightIncrement"] = weightIncrement as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue

        return record
    }

    static func from(record: CKRecord) -> Exercise? {
        guard let idString = record.recordID.recordName as String?,
              let id = UUID(uuidString: idString),
              let name = record["name"] as? String,
              let muscleGroupRaw = record["muscleGroup"] as? String,
              let muscleGroup = MuscleGroup(rawValue: muscleGroupRaw),
              let equipmentRaw = record["equipment"] as? String,
              let equipment = Equipment(rawValue: equipmentRaw) else {
            return nil
        }

        let notes = record["notes"] as? String ?? ""
        let isFavorite = (record["isFavorite"] as? Int64 ?? 0) == 1
        let isDeleted = (record["isDeleted"] as? Int64 ?? 0) == 1
        let defaultWeight = record["defaultWeight"] as? Double ?? 45
        let defaultReps = record["defaultReps"] as? Int64 ?? 10
        let weightIncrement = record["weightIncrement"] as? Double ?? 5
        let createdAt = record["createdAt"] as? Date ?? Date()
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? Date()

        return Exercise(
            id: id,
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            notes: notes,
            isFavorite: isFavorite,
            createdAt: createdAt,
            defaultWeight: defaultWeight,
            defaultReps: Int(defaultReps),
            weightIncrement: weightIncrement,
            modifiedAt: modifiedAt,
            isDeleted: isDeleted
        )
    }
}

// MARK: - Workout CloudKit Extension
extension Workout: Syncable {
    func toCKRecord(in zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: CloudKitRecordType.workout.rawValue, recordID: recordID)

        record["name"] = name as CKRecordValue
        record["notes"] = notes as CKRecordValue
        record["startedAt"] = startedAt as CKRecordValue
        record["modifiedAt"] = modifiedAt as CKRecordValue
        record["isDeleted"] = (isDeleted ? 1 : 0) as CKRecordValue

        if let completedAt = completedAt {
            record["completedAt"] = completedAt as CKRecordValue
        }

        // Encode entries as JSON
        if let entriesData = try? JSONEncoder().encode(entries),
           let entriesJSON = String(data: entriesData, encoding: .utf8) {
            record["entriesJSON"] = entriesJSON as CKRecordValue
        }

        return record
    }

    static func from(record: CKRecord) -> Workout? {
        guard let idString = record.recordID.recordName as String?,
              let id = UUID(uuidString: idString),
              let startedAt = record["startedAt"] as? Date else {
            return nil
        }

        let name = record["name"] as? String ?? ""
        let notes = record["notes"] as? String ?? ""
        let completedAt = record["completedAt"] as? Date
        let isDeleted = (record["isDeleted"] as? Int64 ?? 0) == 1
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? Date()

        // Decode entries from JSON
        var entries: [ExerciseEntry] = []
        if let entriesJSON = record["entriesJSON"] as? String,
           let entriesData = entriesJSON.data(using: .utf8) {
            entries = (try? JSONDecoder().decode([ExerciseEntry].self, from: entriesData)) ?? []
        }

        return Workout(
            id: id,
            name: name,
            entries: entries,
            startedAt: startedAt,
            completedAt: completedAt,
            notes: notes,
            modifiedAt: modifiedAt,
            isDeleted: isDeleted
        )
    }
}
