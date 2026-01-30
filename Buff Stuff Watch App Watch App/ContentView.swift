//
//  ContentView.swift
//  Buff Stuff Watch App Watch App
//
//  Main watch UI showing workout status and metrics
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var workoutManager = WatchWorkoutManager()
    @State private var connectivityManager = WatchConnectivityManager.shared
    @State private var hasAuthorization = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // Accent color matching iOS app
    private let accentColor = Color(hex: "CCFF00")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if workoutManager.isWorkoutActive {
                    activeWorkoutView
                } else {
                    standbyView
                }
            }
        }
        .onAppear {
            setupConnectivity()
            requestAuthorization()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Active Workout View
    private var activeWorkoutView: some View {
        VStack(spacing: 12) {
            // Activity indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("TRACKING")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
            }

            Spacer()

            // Calories - main metric
            VStack(spacing: 2) {
                Text("\(Int(workoutManager.activeCalories))")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                Text("CAL")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Heart rate
            if workoutManager.heartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("BPM")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }

            // Duration
            Text(formatDuration(workoutManager.elapsedTime))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding()
    }

    // MARK: - Standby View
    private var standbyView: some View {
        VStack(spacing: 16) {
            Spacer()

            // App icon
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundColor(accentColor)

            Text("BUFF STUFF")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text("Waiting for workout...")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Spacer()

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(connectivityManager.isReachable ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(connectivityManager.isReachable ? "Connected" : "Connecting...")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }

    // MARK: - Setup

    private func setupConnectivity() {
        connectivityManager.onStartWorkout = {
            Task {
                do {
                    try await workoutManager.startWorkout()
                    connectivityManager.sendWorkoutStarted()
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                    connectivityManager.sendError(error.localizedDescription)
                }
            }
        }

        connectivityManager.onEndWorkout = {
            Task {
                do {
                    let data = try await workoutManager.endWorkout()
                    connectivityManager.sendWorkoutData(data)
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                    connectivityManager.sendError(error.localizedDescription)
                }
            }
        }

        connectivityManager.onCancelWorkout = {
            workoutManager.cancelWorkout()
            connectivityManager.sendWorkoutCancelled()
        }
    }

    private func requestAuthorization() {
        Task {
            do {
                try await workoutManager.requestAuthorization()
                hasAuthorization = true
            } catch {
                errorMessage = "HealthKit access required for tracking"
                showingError = true
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

#Preview {
    ContentView()
}
