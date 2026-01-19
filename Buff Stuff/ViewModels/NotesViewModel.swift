import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class NotesViewModel {
    // MARK: - State
    var changeRequests: [ChangeRequest] = []

    // User Defaults key
    private let changeRequestsKey = "buff_stuff_change_requests"

    // Discord webhook for feedback notifications
    private let discordWebhookURL = "https://discord.com/api/webhooks/1462706107586838660/V9E7S-PIwaIjrMukXKhZn296LiE8pIhTOGSvL7g630cxnxg1ocJHIL_hrg2Rf4iEvlvB"

    // MARK: - Initialization
    init() {
        loadData()
    }

    // MARK: - Data Persistence
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: changeRequestsKey) {
            do {
                changeRequests = try JSONDecoder().decode([ChangeRequest].self, from: data)
                    .sorted { $0.createdAt > $1.createdAt }
            } catch {
                print("⚠️ Failed to decode change requests: \(error.localizedDescription)")
                backupCorruptedData(data, key: changeRequestsKey)
            }
        }
    }

    /// Backup corrupted data for potential recovery
    private func backupCorruptedData(_ data: Data, key: String) {
        let backupKey = "\(key)_backup_\(Int(Date().timeIntervalSince1970))"
        UserDefaults.standard.set(data, forKey: backupKey)
        print("📦 Backed up corrupted data to: \(backupKey)")
    }

    private func saveChangeRequests() {
        if let encoded = try? JSONEncoder().encode(changeRequests) {
            UserDefaults.standard.set(encoded, forKey: changeRequestsKey)
        }
    }

    // MARK: - Change Request Management
    func addChangeRequest(_ content: String) {
        let request = ChangeRequest(content: content)
        changeRequests.insert(request, at: 0)
        saveChangeRequests()
        sendToDiscord(content)
        triggerHaptic(.light)
    }

    func deleteChangeRequest(_ request: ChangeRequest) {
        changeRequests.removeAll { $0.id == request.id }
        saveChangeRequests()
        triggerHaptic(.light)
    }

    // MARK: - Discord Notification
    private func sendToDiscord(_ content: String) {
        guard let url = URL(string: discordWebhookURL) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "content": "📝 **New Feedback**\n\(content)"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // Fire and forget - don't block UI or handle errors
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Haptic Feedback
    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
