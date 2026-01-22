import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class NotesViewModel {
    // MARK: - State
    var isSending: Bool = false
    var showSuccess: Bool = false

    // Discord webhook URL loaded from Info.plist (set via Secrets.xcconfig)
    private var discordWebhookURL: String? {
        Bundle.main.infoDictionary?["DiscordWebhookURL"] as? String
    }

    // MARK: - Send Feedback
    func sendFeedback(_ content: String) {
        guard !content.isEmpty else { return }

        isSending = true

        Task {
            await sendToDiscord(content)
            isSending = false
            showSuccess = true
            triggerHaptic(.success)
        }
    }

    // MARK: - Discord Notification
    private func sendToDiscord(_ content: String) async {
        guard let webhookURLString = discordWebhookURL,
              !webhookURLString.isEmpty,
              let url = URL(string: webhookURLString) else {
            print("⚠️ Discord webhook URL not configured. Set DISCORD_WEBHOOK_URL in Secrets.xcconfig")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": "📝 **New Feedback**\n\(content)"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // Send request (ignore response for simplicity)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Haptic Feedback
    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
