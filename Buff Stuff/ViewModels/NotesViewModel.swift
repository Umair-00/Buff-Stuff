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

    // MARK: - Initialization
    init() {
        loadData()
    }

    // MARK: - Data Persistence
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: changeRequestsKey),
           let decoded = try? JSONDecoder().decode([ChangeRequest].self, from: data) {
            changeRequests = decoded.sorted { $0.createdAt > $1.createdAt }
        }
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
        triggerHaptic(.light)
    }

    func deleteChangeRequest(_ request: ChangeRequest) {
        changeRequests.removeAll { $0.id == request.id }
        saveChangeRequests()
        triggerHaptic(.light)
    }

    // MARK: - Haptic Feedback
    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
