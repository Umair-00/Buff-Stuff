# Buff Stuff - watchOS Companion App

## Overview

The watchOS companion app enables **active calorie and heart rate tracking** during workouts. When a workout is started on the iPhone, the watch automatically begins an `HKWorkoutSession` that actively tracks metrics using the watch's sensors.

**Key Insight:** iOS `HKWorkoutSession` only shows a Dynamic Island indicator - it does NOT trigger the Apple Watch to actively track. The watch must run its own workout session for real sensor data.

## Architecture

```
iOS App                              watchOS App
─────────                            ───────────
startWorkout() ───WCSession──────────> Start HKWorkoutSession
                                       (Active HR/calorie tracking begins)
logSet()       ──────────────────────> (No action - phone handles logging)
finishWorkout() ──WCSession──────────> End HKWorkoutSession
                                       ← Return calories/HR data
cancelWorkout() ──WCSession──────────> Discard session
```

## Files

### iOS App

| File | Purpose |
|------|---------|
| `Buff Stuff/Services/WatchConnectivityManager.swift` | WCSession handling - sends commands to watch |
| `Buff Stuff/WatchMessage.swift` | Shared message types (commands, responses, data) |
| `Buff Stuff/ViewModels/WorkoutViewModel.swift` | Calls watch manager in `startWorkout()`, `finishWorkout()`, `cancelWorkout()` |

### watchOS App

| File | Purpose |
|------|---------|
| `Buff Stuff Watch App Watch App/Buff_Stuff_Watch_AppApp.swift` | App entry point |
| `Buff Stuff Watch App Watch App/ContentView.swift` | Watch UI (standby + active workout views) |
| `Buff Stuff Watch App Watch App/WatchWorkoutManager.swift` | HKWorkoutSession + HKLiveWorkoutBuilder |
| `Buff Stuff Watch App Watch App/WatchConnectivityManager.swift` | WCSession handling - receives commands from iOS |
| `Buff Stuff Watch App Watch App/WatchMessage.swift` | Shared message types (duplicated for watch target) |

## Communication Protocol

### Commands (iOS → Watch)

```swift
enum WatchCommand: String, Codable {
    case startWorkout   // Begin HKWorkoutSession
    case endWorkout     // End session, return data
    case cancelWorkout  // End session, discard data
    case ping           // Check reachability
}
```

### Responses (Watch → iOS)

```swift
enum WatchResponse: String, Codable {
    case workoutStarted
    case workoutEnded      // Includes WatchWorkoutData
    case workoutCancelled
    case error
    case pong
}
```

### Workout Data (returned on end)

```swift
struct WatchWorkoutData: Codable {
    let activeCalories: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let startDate: Date
    let endDate: Date
}
```

## Watch UI States

### Standby (no active workout)
- Buff Stuff logo (dumbbell icon)
- "Waiting for workout..." text
- Connection status indicator (green = connected, orange = connecting)

### Active Workout
- Green "TRACKING" indicator
- Large calorie count (lime accent color)
- Heart rate with BPM
- Elapsed time

## HealthKit Configuration

### Entitlements (`Buff Stuff Watch App Watch App.entitlements`)
```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
```

### Info.plist Keys (via build settings)
- `NSHealthShareUsageDescription` - Read HR during workouts
- `NSHealthUpdateUsageDescription` - Save workouts to Health
- `WKBackgroundModes` - `workout-processing`
- `WKRunsIndependentlyOfCompanionApp` - NO (requires iOS app)

## Workout Session Details

The watch uses `HKWorkoutSession` with `HKLiveWorkoutBuilder`:

- **Activity Type:** `.functionalStrengthTraining`
- **Location:** `.indoor`
- **Tracked Metrics:**
  - Active Energy Burned (calories)
  - Heart Rate (BPM)
- **Data Source:** `HKLiveWorkoutDataSource` for real-time updates

## Deployment

### Via TestFlight (Recommended)
1. Archive iOS app: `Product → Archive`
2. Distribute via App Store Connect
3. Install from TestFlight - watch app installs automatically

### Direct to Watch (Unreliable)
- Requires Developer Mode on watch
- Watch must show "Connected" in Xcode Devices
- Often fails with network/tunnel errors

## Known Issues

1. **WCSession in Simulator** - Watch Connectivity doesn't work in simulators, must test on physical devices
2. **"Not enough storage" error** - Usually means deployment target mismatch or signing issues, not actual storage
3. **Watch connection flaky** - USB connection to iPhone is more reliable than WiFi

## Future Enhancements

- Heart Rate Zones display
- Heart Rate Recovery tracking (post-workout)
- Start workout from watch (bidirectional)
- Show current exercise name on watch
- Rest timer between sets
- Haptic alerts for milestones
