//
//  WatchMessage.swift
//  Buff Stuff
//
//  Shared message types for iOS ↔ watchOS communication
//

import Foundation

// MARK: - Commands (iOS → Watch)

/// Commands sent from iOS app to watchOS app
enum WatchCommand: String, Codable {
    case startWorkout
    case endWorkout
    case cancelWorkout
    case ping
}

// MARK: - Responses (Watch → iOS)

/// Responses sent from watchOS app to iOS app
enum WatchResponse: String, Codable {
    case workoutStarted
    case workoutEnded
    case workoutCancelled
    case error
    case pong
}

// MARK: - Workout Data

/// Workout data returned from watch when session ends
struct WatchWorkoutData: Codable {
    let activeCalories: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let startDate: Date
    let endDate: Date
}

// MARK: - Message Keys

/// Keys for WCSession message dictionaries
enum WatchMessageKey: String {
    case command
    case response
    case workoutData
    case error
}
