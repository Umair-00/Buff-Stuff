import Foundation
import SwiftUI

// MARK: - Exercise Model
struct Exercise: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var notes: String
    var isFavorite: Bool
    var createdAt: Date

    // Default values for quick logging
    var defaultWeight: Double
    var defaultReps: Int
    var weightIncrement: Double

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup = .other,
        equipment: Equipment = .barbell,
        notes: String = "",
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        defaultWeight: Double = 45,
        defaultReps: Int = 10,
        weightIncrement: Double = 5
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.defaultWeight = defaultWeight
        self.defaultReps = defaultReps
        self.weightIncrement = weightIncrement
    }
}

// MARK: - Muscle Group
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case glutes = "Glutes"
    case core = "Core"
    case forearms = "Forearms"
    case cardio = "Cardio"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.strengthtraining.traditional"
        case .triceps: return "figure.strengthtraining.functional"
        case .legs: return "figure.run"
        case .glutes: return "figure.stairs"
        case .core: return "figure.core.training"
        case .forearms: return "hand.raised.fill"
        case .cardio: return "heart.fill"
        case .other: return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .chest: return Color(hex: "FF6B6B")
        case .back: return Color(hex: "4ECDC4")
        case .shoulders: return Color(hex: "45B7D1")
        case .biceps: return Color(hex: "96CEB4")
        case .triceps: return Color(hex: "FFEAA7")
        case .legs: return Color(hex: "DDA0DD")
        case .glutes: return Color(hex: "FF8C42")
        case .core: return Color(hex: "98D8C8")
        case .forearms: return Color(hex: "F7DC6F")
        case .cardio: return Color(hex: "FF5252")
        case .other: return Theme.Colors.steel
        }
    }
}

// MARK: - Equipment
enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case kettlebell = "Kettlebell"
    case resistanceBand = "Band"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .cable: return "cable.connector"
        case .machine: return "gearshape.fill"
        case .bodyweight: return "figure.stand"
        case .kettlebell: return "scalemass.fill"
        case .resistanceBand: return "lasso"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Sample Exercises
extension Exercise {
    static let samples: [Exercise] = [
        Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell, defaultWeight: 135, defaultReps: 10),
        Exercise(name: "Squat", muscleGroup: .legs, equipment: .barbell, defaultWeight: 185, defaultReps: 8),
        Exercise(name: "Deadlift", muscleGroup: .back, equipment: .barbell, defaultWeight: 225, defaultReps: 5),
        Exercise(name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell, defaultWeight: 95, defaultReps: 8),
        Exercise(name: "Barbell Row", muscleGroup: .back, equipment: .barbell, defaultWeight: 135, defaultReps: 10),
        Exercise(name: "Bicep Curl", muscleGroup: .biceps, equipment: .dumbbell, defaultWeight: 30, defaultReps: 12, weightIncrement: 2.5),
        Exercise(name: "Tricep Pushdown", muscleGroup: .triceps, equipment: .cable, defaultWeight: 50, defaultReps: 12, weightIncrement: 5),
        Exercise(name: "Lat Pulldown", muscleGroup: .back, equipment: .cable, defaultWeight: 120, defaultReps: 10),
        Exercise(name: "Leg Press", muscleGroup: .legs, equipment: .machine, defaultWeight: 270, defaultReps: 12, weightIncrement: 10),
        Exercise(name: "Pull-ups", muscleGroup: .back, equipment: .bodyweight, defaultWeight: 0, defaultReps: 8),
    ]
}
