//
//  WatchConnectivityManager.swift
//  Buff Stuff
//
//  Manages Watch Connectivity communication with watchOS companion app
//

import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
class WatchConnectivityManager: NSObject {
    // MARK: - Singleton
    static let shared = WatchConnectivityManager()

    // MARK: - State
    private(set) var isReachable: Bool = false
    private(set) var isWatchAppInstalled: Bool = false
    private(set) var watchWorkoutActive: Bool = false
    private(set) var lastWatchWorkoutData: WatchWorkoutData?
    private(set) var lastError: String?

    // MARK: - Callbacks
    var onWorkoutDataReceived: ((WatchWorkoutData) -> Void)?
    var onWatchStatusChanged: ((Bool) -> Void)?

    // MARK: - Private
    private var session: WCSession?

    // MARK: - Initialization
    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[Watch] WCSession not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Public Methods

    /// Send command to start workout on watch
    func startWatchWorkout() {
        sendCommand(.startWorkout)
    }

    /// Send command to end workout on watch
    func endWatchWorkout() {
        sendCommand(.endWorkout)
    }

    /// Send command to cancel workout on watch (no data saved)
    func cancelWatchWorkout() {
        sendCommand(.cancelWorkout)
    }

    /// Check if watch is reachable
    func pingWatch() {
        sendCommand(.ping)
    }

    // MARK: - Private Methods

    private func sendCommand(_ command: WatchCommand) {
        guard let session = session, session.isReachable else {
            lastError = "Apple Watch not reachable"
            print("[Watch] Cannot send command - watch not reachable")
            return
        }

        let message: [String: Any] = [
            WatchMessageKey.command.rawValue: command.rawValue
        ]

        print("[Watch] Sending command: \(command.rawValue)")

        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.handleReply(reply)
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.lastError = error.localizedDescription
                print("[Watch] Error sending command: \(error.localizedDescription)")
            }
        })
    }

    private func handleReply(_ reply: [String: Any]) {
        guard let responseRaw = reply[WatchMessageKey.response.rawValue] as? String,
              let response = WatchResponse(rawValue: responseRaw) else {
            print("[Watch] Invalid response received")
            return
        }

        print("[Watch] Received response: \(response.rawValue)")

        switch response {
        case .workoutStarted:
            watchWorkoutActive = true
            lastError = nil

        case .workoutEnded:
            watchWorkoutActive = false
            if let dataEncoded = reply[WatchMessageKey.workoutData.rawValue] as? Data,
               let workoutData = try? JSONDecoder().decode(WatchWorkoutData.self, from: dataEncoded) {
                lastWatchWorkoutData = workoutData
                onWorkoutDataReceived?(workoutData)
                print("[Watch] Received workout data: \(workoutData.activeCalories) calories")
            }

        case .workoutCancelled:
            watchWorkoutActive = false
            lastWatchWorkoutData = nil

        case .error:
            lastError = reply[WatchMessageKey.error.rawValue] as? String
            print("[Watch] Error from watch: \(lastError ?? "unknown")")

        case .pong:
            print("[Watch] Ping successful")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.lastError = error.localizedDescription
                print("[Watch] Activation error: \(error.localizedDescription)")
            } else {
                print("[Watch] Session activated: \(activationState.rawValue)")
            }
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("[Watch] Session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("[Watch] Session deactivated - reactivating")
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.onWatchStatusChanged?(session.isReachable)
            print("[Watch] Reachability changed: \(session.isReachable)")
        }
    }

    // Handle messages from watch (e.g., if watch initiates communication)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.handleReply(message)
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleReply(message)
        }
    }
}
