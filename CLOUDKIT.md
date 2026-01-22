# CloudKit Integration Guide

This document tracks the CloudKit integration for Buff Stuff.

---

## Overview

**Goal:** Sync workout data across devices via iCloud private database.

**Benefits:**
- Multi-device sync (iPhone/iPad/Watch)
- Automatic backup
- New device restore
- No login required (uses existing iCloud)

---

## Implementation Steps

### Step 1: Xcode Project Setup
- [ ] Enable CloudKit capability
- [ ] Enable Push Notifications capability
- [ ] Create iCloud container: `iCloud.com.buffstuff.Buff-Stuff`

### Step 2: CloudKitManager Service
- [ ] Create `CloudKitManager.swift`
- [ ] Account status checking
- [ ] Custom zone creation
- [ ] Basic CRUD operations

### Step 3: Sync Models
- [ ] Create `SyncState.swift` (sync metadata)
- [ ] Create `CKRecord+Models.swift` (Syncable protocol)
- [ ] Add CKRecord conversion to Exercise
- [ ] Add CKRecord conversion to Workout

### Step 4: SyncEngine
- [ ] Create `SyncEngine.swift`
- [ ] Push local changes
- [ ] Pull remote changes
- [ ] Conflict resolution
- [ ] Offline queue

### Step 5: ViewModel Integration
- [ ] Modify WorkoutViewModel to trigger sync
- [ ] Add methods to apply remote changes

### Step 6: Settings UI
- [ ] Add iCloud sync section
- [ ] Sync toggle
- [ ] Status indicator
- [ ] Manual sync button

### Step 7: Testing
- [ ] Unit tests for CKRecord conversion
- [ ] Multi-device manual testing

---

## CloudKit Record Schema

### Exercise Record
| Field | Type | Notes |
|-------|------|-------|
| id | String | UUID as recordName |
| name | String | |
| muscleGroup | String | Enum raw value |
| equipment | String | Enum raw value |
| notes | String | |
| isFavorite | Int64 | 0 or 1 |
| isDeleted | Int64 | Soft delete flag |
| defaultWeight | Double | |
| defaultReps | Int64 | |
| weightIncrement | Double | |
| createdAt | Date | |
| modifiedAt | Date | For conflict resolution |

### Workout Record
| Field | Type | Notes |
|-------|------|-------|
| id | String | UUID as recordName |
| name | String | |
| startedAt | Date | |
| completedAt | Date | Optional |
| notes | String | |
| entriesJSON | String | JSON-encoded [ExerciseEntry] |
| isDeleted | Int64 | Soft delete flag |
| modifiedAt | Date | For conflict resolution |

---

## UserDefaults Keys

```swift
// Existing keys (unchanged)
buff_stuff_exercises
buff_stuff_workouts
buff_stuff_active_workout
buff_stuff_healthkit_enabled
buff_stuff_synced_workout_ids
buff_stuff_schema_version

// New CloudKit keys
buff_stuff_cloudkit_enabled       // Bool: User toggle
buff_stuff_cloudkit_migrated      // Bool: Initial upload done
buff_stuff_sync_metadata          // Data: Server change token, etc.
buff_stuff_pending_sync_changes   // Data: Offline queue
buff_stuff_last_sync_date         // Date
```

---

## Sync Strategy

### When to Push (Local → Cloud)
| Trigger | Action |
|---------|--------|
| Exercise created/updated/deleted | Push immediately |
| Workout finished | Push immediately |
| Set logged in active workout | Debounce 30s, then push |
| App enters background | Push pending changes |

### When to Pull (Cloud → Local)
| Trigger | Action |
|---------|--------|
| App launch | Fetch changes since last token |
| App enters foreground | Fetch changes since last token |
| CloudKit push notification | Fetch changes |

### Conflict Resolution
- Compare `modifiedAt` timestamps
- Last-writer-wins
- Active workout always prefers local device

---

## File Structure

```
Buff Stuff/
├── Services/
│   ├── HealthKitManager.swift    # Existing
│   ├── CloudKitManager.swift     # NEW
│   └── SyncEngine.swift          # NEW
├── Models/
│   ├── Exercise.swift            # Modified (add Syncable)
│   ├── Workout.swift             # Modified (add Syncable)
│   └── SyncState.swift           # NEW
└── Extensions/
    └── CKRecord+Models.swift     # NEW
```

---

## Progress Log

### [Date] - Step 1: Xcode Setup
_Not started_

---

## Troubleshooting

### Common Issues

**"iCloud account not available"**
- User not signed into iCloud on device
- Show message in Settings UI

**"Quota exceeded"**
- User's iCloud storage full
- Alert user, continue local-only

**"Network unavailable"**
- Queue changes locally
- Sync when connection returns

---

## Testing Checklist

- [ ] Fresh install → enable sync → data uploads
- [ ] New device → enable sync → data downloads
- [ ] Log workout on device A → appears on device B
- [ ] Airplane mode → log workout → reconnect → syncs
- [ ] Edit same exercise on two devices → conflict resolved
- [ ] Disable sync → local data preserved
