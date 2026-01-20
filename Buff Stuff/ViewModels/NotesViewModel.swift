import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class NotesViewModel {
    // MARK: - State
    var isSending: Bool = false
    var showSuccess: Bool = false

    // Discord webhook for feedback notifications
    private let discordWebhookURL = "https://discord.com/api/webhooks/1462706107586838660/V9E7S-PIwaIjrMukXKhZn296LiE8pIhTOGSvL7g630cxnxg1ocJHIL_hrg2Rf4iEvlvB"

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
        guard let url = URL(string: discordWebhookURL) else { return }

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
