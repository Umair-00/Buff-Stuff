//
//  WatchConnectivityManager.swift
//  Buff Stuff Watch App
//
//  Manages Watch Connectivity communication with iOS companion app
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = WatchConnectivityManager()

    // MARK: - State
    @Published var isReachable: Bool = false

    // MARK: - Callbacks
    var onStartWorkout: (() -> Void)?
    var onEndWorkout: (() -> Void)?
    var onCancelWorkout: (() -> Void)?

    // MARK: - Private
    private var session: WCSession?
    private var pendingReplyHandler: (([String: Any]) -> Void)?

    // MARK: - Initialization
    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("[WatchConn] WCSession not supported")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        print("[WatchConn] Session setup complete")
    }

    // MARK: - Send Responses

    /// Send workout data back to iOS when workout ends
    func sendWorkoutData(_ data: WatchWorkoutData) {
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("[WatchConn] Failed to encode workout data")
            sendError("Failed to encode workout data")
            return
        }

        let response: [String: Any] = [
            WatchMessageKey.response.rawValue: WatchResponse.workoutEnded.rawValue,
            WatchMessageKey.workoutData.rawValue: encoded
        ]

        print("[WatchConn] Sending workout data: \(data.activeCalories) calories")

        if let handler = pendingReplyHandler {
            handler(response)
            pendingReplyHandler = nil
        } else {
            // Send as standalone message if no pending reply
            session?.sendMessage(response, replyHandler: nil, errorHandler: { error in
                print("[WatchConn] Error sending workout data: \(error.localizedDescription)")
            })
        }
    }

    func sendWorkoutStarted() {
        let response: [String: Any] = [
            WatchMessageKey.response.rawValue: WatchResponse.workoutStarted.rawValue
        ]

        print("[WatchConn] Sending workoutStarted")

        if let handler = pendingReplyHandler {
            handler(response)
            pendingReplyHandler = nil
        } else {
            session?.sendMessage(response, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendWorkoutCancelled() {
        let response: [String: Any] = [
            WatchMessageKey.response.rawValue: WatchResponse.workoutCancelled.rawValue
        ]

        print("[WatchConn] Sending workoutCancelled")

        if let handler = pendingReplyHandler {
            handler(response)
            pendingReplyHandler = nil
        } else {
            session?.sendMessage(response, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendError(_ message: String) {
        let response: [String: Any] = [
            WatchMessageKey.response.rawValue: WatchResponse.error.rawValue,
            WatchMessageKey.error.rawValue: message
        ]

        print("[WatchConn] Sending error: \(message)")

        if let handler = pendingReplyHandler {
            handler(response)
            pendingReplyHandler = nil
        } else {
            session?.sendMessage(response, replyHandler: nil, errorHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("[WatchConn] Activation error: \(error.localizedDescription)")
            } else {
                print("[WatchConn] Session activated: \(activationState.rawValue)")
            }
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            print("[WatchConn] Reachability changed: \(session.isReachable)")
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let commandRaw = message[WatchMessageKey.command.rawValue] as? String,
              let command = WatchCommand(rawValue: commandRaw) else {
            print("[WatchConn] Invalid command received")
            replyHandler([WatchMessageKey.response.rawValue: WatchResponse.error.rawValue])
            return
        }

        print("[WatchConn] Received command: \(command.rawValue)")

        Task { @MainActor in
            self.pendingReplyHandler = replyHandler

            switch command {
            case .startWorkout:
                self.onStartWorkout?()
            case .endWorkout:
                self.onEndWorkout?()
            case .cancelWorkout:
                self.onCancelWorkout?()
            case .ping:
                replyHandler([WatchMessageKey.response.rawValue: WatchResponse.pong.rawValue])
                self.pendingReplyHandler = nil
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle messages without reply handler
        guard let commandRaw = message[WatchMessageKey.command.rawValue] as? String,
              let command = WatchCommand(rawValue: commandRaw) else {
            return
        }

        print("[WatchConn] Received command (no reply): \(command.rawValue)")

        Task { @MainActor in
            switch command {
            case .startWorkout:
                self.onStartWorkout?()
            case .endWorkout:
                self.onEndWorkout?()
            case .cancelWorkout:
                self.onCancelWorkout?()
            case .ping:
                break
            }
        }
    }
}
