# Buff Stuff - iOS Workout Tracker

## Project Overview

Buff Stuff is an iOS workout tracking app designed for strength training. The app prioritizes speed and efficiency for logging sets during gym sessions with minimal friction.

**Core Features:**
- Real-time workout logging with quick set entry
- Exercise library with customizable defaults
- Workout history with analytics (volume, sets, duration)
- Notes section for feature ideas and change requests

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (iOS 17+)
- **State Management:** @Observable macro, @MainActor
- **Data Persistence:** UserDefaults with Codable JSON encoding
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
│   ├── WorkoutViewModel.swift   # Workouts, exercises, active session state
│   └── NotesViewModel.swift     # Change requests state
└── Views/
    ├── TodayView.swift          # Active workout display
    ├── HistoryView.swift        # Workout history + analytics
    ├── ExerciseLibraryView.swift # Browse/manage exercises
    ├── NotesView.swift          # Notes management
    ├── QuickLogSheet.swift      # Fast set logging modal
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

## UserDefaults Keys

```swift
buff_stuff_exercises
buff_stuff_workouts
buff_stuff_active_workout
buff_stuff_change_requests
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

**Tab Navigation:** 4 tabs with center FAB button
1. Today - Active workout logging
2. Exercises - Library management
3. History - Past workouts
4. Notes - Feature requests

**Quick Log Flow:**
1. Tap FAB (+) to open exercise picker
2. Select exercise to open QuickLogSheet
3. Adjust weight/reps and log set
4. Repeat or close

## Important Notes

- App is fully offline (no backend)
- Uses iOS 17+ APIs (@Observable)
- Forces dark color scheme
- Warmup sets excluded from volume calculations
- Workouts auto-name from muscle groups if no custom name
