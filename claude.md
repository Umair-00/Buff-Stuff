# Buff Stuff - iOS Workout Tracker

## Project Overview

Buff Stuff is an iOS workout tracking app designed for strength training. The app prioritizes speed and efficiency for logging sets during gym sessions with minimal friction.

**Core Features:**
- Real-time workout logging with quick set entry
- Exercise library with customizable defaults
- Workout history with analytics (volume, sets, duration)
- Smart suggestions for progressive overload
- HealthKit integration (workout sync, live sessions)
- Notes section for feature ideas and change requests

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (iOS 17+)
- **State Management:** @Observable macro, @MainActor
- **Data Persistence:** UserDefaults with Codable JSON encoding
- **Health Integration:** HealthKit (workout sync, live sessions, HR/calories)
- **Build System:** Xcode project

## Architecture

**Pattern:** MVVM (Model-View-ViewModel)

```
Buff Stuff/
├── Buff_StuffApp.swift          # App entry point
├── ContentView.swift            # Main tab navigation
├── Theme.swift                  # Centralized design system
├── Models/
│   ├── Workout.swift            # Workout session with ExerciseEntry
│   ├── Exercise.swift           # Exercise definition + MuscleGroup/Equipment enums
│   ├── WorkoutSet.swift         # Individual set (weight × reps)
│   └── ChangeRequest.swift      # Notes/feature requests
├── ViewModels/
│   ├── WorkoutViewModel.swift   # Workouts, exercises, active session, suggestions
│   └── NotesViewModel.swift     # Change requests state
├── Services/
│   └── HealthKitManager.swift   # HealthKit sync, live workout sessions
└── Views/
    ├── TodayView.swift          # Active workout display
    ├── HistoryView.swift        # Workout history + analytics
    ├── ExerciseLibraryView.swift # Browse/manage exercises
    ├── NotesView.swift          # Notes management
    ├── SettingsView.swift       # App settings, HealthKit toggle, data export
    ├── QuickLogSheet.swift      # Fast set logging modal + suggestions
    ├── ExercisePickerSheet.swift # Exercise selection
    └── NewExerciseSheet.swift   # Create exercise form
```

## Key Conventions

### State Management
- ViewModels use `@Observable` and `@MainActor`
- Views access ViewModels via `@Environment()`
- ContentView owns ViewModels as `@State` and passes via `.environment()`
- Use `@Bindable` for two-way form bindings

### Data Persistence
- UserDefaults keys prefixed with `buff_stuff_`
- All models conform to `Codable`
- ViewModels handle load/save operations

### Theming
- All styling lives in `Theme.swift`
- Use `Theme.Colors`, `Theme.Spacing`, `Theme.Typography`
- Dark mode only with electric lime accent (#CCFF00)
- Custom ViewModifiers: `CardStyle`, `AccentButtonStyle`, `GhostButtonStyle`

### Haptic Feedback
- Use `UIImpactFeedbackGenerator` for adjustments
- Use `UINotificationFeedbackGenerator` for success/warning
- Apply feedback on user actions consistently

### Naming
- Views: `*View.swift` or `*Sheet.swift`
- ViewModels: `*ViewModel.swift`
- Models: Singular names (Workout, Exercise)
- Use `// MARK: -` comments for section organization

## Data Models

### Workout
- Contains `[ExerciseEntry]` which group sets by exercise
- Tracks `startedAt`, `completedAt`, `notes`
- Computed: `isActive`, `duration`, `totalVolume`, `totalSets`, `muscleGroups`

### Exercise
- Includes `muscleGroup: MuscleGroup`, `equipment: Equipment`
- Defaults: `defaultWeight`, `defaultReps`, `weightIncrement`
- Has `isFavorite` flag

### WorkoutSet
- Core logging unit: `weight`, `reps`, `isWarmup`
- Computed: `volume` (weight × reps, 0 if warmup)

### Enums
- `MuscleGroup`: 11 options with color and icon
- `Equipment`: 8 options with icon

## Progressive Overload Algorithm

The History tab tracks progressive overload using volume-based comparison.

**Core Metric:** Volume = weight × reps (from top set per session)
- Top set = working set with highest volume in a session
- Warmup sets excluded (return 0 volume)

**Requirements:**
- Minimum 4 sessions needed to calculate progress
- Fewer than 4 sessions shows "new exercise" status

**Calculation:**
1. Take 2 most recent sessions → compute average volume (recentAvg)
2. Take 2 sessions before those (sessions 3-4) → compute average volume (baselineAvg)
3. Percent change = ((recentAvg - baselineAvg) / baselineAvg) × 100

**Status Thresholds:**
- `> +2%` → Progressing (green)
- `< -2%` → Declining (red)
- `-2% to +2%` → Plateau (yellow)

**Implementation:** `WorkoutViewModel.allExerciseProgress(in:)` at line ~505

## Smart Suggestions

The QuickLogSheet displays contextual suggestions based on workout history.

**Suggestion Types:**
- `progressiveOverload` - User hit same weight×reps 2+ times → suggest increase
- `consistentPerformance` - Show last workout stats, encourage consistency
- `newExercise` - Less than 2 data points, prompt to keep logging

**Logic (`WorkoutViewModel.getSuggestion(for:)`):**
1. Get last 4 sessions for the exercise (90-day window)
2. Check if user hit current weight×reps combo 2+ times
3. If yes and reps ≥ 5: suggest weight + `exercise.weightIncrement`
4. Otherwise: show encouraging "Last: X×Y — keep pushing" message

**UI Behavior:**
- Banner appears below exercise name in QuickLogSheet
- Tapping progressive overload suggestion auto-fills suggested weight
- Non-blocking, user can ignore

**Implementation:** `WorkoutViewModel.getSuggestion(for:)` and `SuggestionBanner` in QuickLogSheet.swift

## HealthKit Integration

Workouts sync to Apple Health and display a live workout indicator.

**Features:**
- Completed workouts saved to HealthKit with duration and activity type
- Live `HKWorkoutSession` shows Dynamic Island indicator during active workout
- Queries Apple Watch data (HR, calories) for workout time window

**HealthKitManager (Singleton):**
- `shared` - Access via `HealthKitManager.shared`
- `isAvailable` - Device supports HealthKit
- `isAuthorized` - User granted permissions
- `isHealthKitSyncEnabled` - User toggle in Settings

**Key Methods:**
- `requestAuthorization()` - Prompt for HealthKit access
- `startWorkoutSession()` - Begin live session (called on workout start)
- `endWorkoutSession()` - End live session (called on finish/cancel)
- `saveWorkout(_:)` - Save completed workout to Health app

**Workout Session Flow:**
1. User starts workout → `startWorkoutSession()` called
2. Dynamic Island shows workout indicator (blue running person)
3. User finishes/cancels → `endWorkoutSession()` called
4. Completed workout synced to HealthKit

**Note:** iOS `HKWorkoutSession` does NOT trigger Apple Watch to actively track HR/calories. That requires a watchOS companion app. The current implementation shows the live indicator but watch data comes from passive tracking only.

**Implementation:** `HealthKitManager.swift` in Services/

## UserDefaults Keys

```swift
buff_stuff_exercises
buff_stuff_workouts
buff_stuff_active_workout
buff_stuff_change_requests
buff_stuff_healthkit_enabled
buff_stuff_synced_workout_ids
buff_stuff_schema_version
```

## Common Tasks

### Adding a New View
1. Create view file in `Views/`
2. Access ViewModel via `@Environment(WorkoutViewModel.self)`
3. Use Theme constants for styling
4. Add haptic feedback for interactions

### Adding a New Model Property
1. Add property to model with default value
2. Ensure Codable conformance still works
3. Update relevant ViewModel methods
4. Add UI in appropriate views

### Modifying Theme
1. Edit `Theme.swift` constants
2. Colors, spacing, typography, and modifiers are all centralized

### Adding Persistence for New Data
1. Add UserDefaults key constant
2. Implement `load*()` and `save*()` in ViewModel
3. Call load in ViewModel init
4. Call save after mutations

## UI Structure

**Tab Navigation:** 5 tabs with center FAB button
1. Today - Active workout logging
2. Exercises - Library management
3. (center) FAB - Quick add exercise
4. History - Past workouts + analytics
5. Settings - HealthKit toggle, data export/import, app info

**Quick Log Flow:**
1. Tap FAB (+) to open exercise picker
2. Select exercise to open QuickLogSheet
3. Smart suggestion banner shows (if applicable)
4. Adjust weight/reps and log set
5. Repeat or close

## Important Notes

- App is fully offline (no backend)
- Uses iOS 17+ APIs (@Observable)
- Forces dark color scheme
- Warmup sets excluded from volume calculations
- Workouts auto-name from muscle groups if no custom name
- HealthKit sync is opt-in (toggle in Settings)
- Live workout indicator requires HealthKit enabled
- Data export/import uses JSON format with schema versioning
