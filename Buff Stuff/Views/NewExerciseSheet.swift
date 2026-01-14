//
//  NewExerciseSheet.swift
//  Buff Stuff
//
//  Create a custom exercise
//

import SwiftUI

struct NewExerciseSheet: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var defaultWeight: Double = 45
    @State private var defaultReps: Int = 10
    @State private var weightIncrement: Double = 5
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Name input
                        nameInput

                        // Muscle group picker
                        muscleGroupPicker

                        // Equipment picker
                        equipmentPicker

                        // Defaults section
                        defaultsSection

                        // Notes
                        notesInput
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    // MARK: - Name Input
    private var nameInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("NAME")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            TextField("e.g., Incline Bench Press", text: $name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(Theme.Spacing.md)
                .cardStyle()
        }
    }

    // MARK: - Muscle Group Picker
    private var muscleGroupPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("MUSCLE GROUP")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(MuscleGroup.allCases) { group in
                        Button {
                            muscleGroup = group
                        } label: {
                            VStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: group.icon)
                                    .font(.title3)
                                    .foregroundColor(muscleGroup == group ? Theme.Colors.background : group.color)

                                Text(group.rawValue)
                                    .font(Theme.Typography.captionSmall)
                                    .foregroundColor(muscleGroup == group ? Theme.Colors.background : Theme.Colors.textSecondary)
                            }
                            .frame(width: 70, height: 70)
                            .background(muscleGroup == group ? group.color : Theme.Colors.surface)
                            .cornerRadius(Theme.Radius.medium)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Equipment Picker
    private var equipmentPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("EQUIPMENT")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                ForEach(Equipment.allCases) { equip in
                    Button {
                        equipment = equip
                    } label: {
                        HStack {
                            Image(systemName: equip.icon)
                                .foregroundColor(equipment == equip ? Theme.Colors.accent : Theme.Colors.textMuted)

                            Text(equip.rawValue)
                                .font(Theme.Typography.body)
                                .foregroundColor(equipment == equip ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)

                            Spacer()

                            if equipment == equip {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.Colors.accent)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(equipment == equip ? Theme.Colors.surfaceElevated : Theme.Colors.surface)
                        .cornerRadius(Theme.Radius.medium)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Defaults Section
    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("DEFAULT VALUES")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            Text("These will be suggested when logging sets")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: Theme.Spacing.md) {
                // Weight
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Weight (lbs)")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)

                    HStack {
                        Button {
                            defaultWeight = max(0, defaultWeight - weightIncrement)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 36, height: 36)
                                .background(Theme.Colors.surfaceElevated)
                                .cornerRadius(Theme.Radius.small)
                        }

                        Text("\(Int(defaultWeight))")
                            .font(Theme.Typography.mono(20))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 60)

                        Button {
                            defaultWeight += weightIncrement
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 36, height: 36)
                                .background(Theme.Colors.surfaceElevated)
                                .cornerRadius(Theme.Radius.small)
                        }
                    }
                    .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(Theme.Spacing.md)
                .cardStyle()

                // Reps
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Reps")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)

                    HStack {
                        Button {
                            defaultReps = max(1, defaultReps - 1)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 36, height: 36)
                                .background(Theme.Colors.surfaceElevated)
                                .cornerRadius(Theme.Radius.small)
                        }

                        Text("\(defaultReps)")
                            .font(Theme.Typography.mono(20))
                            .foregroundColor(Theme.Colors.accent)
                            .frame(width: 60)

                        Button {
                            defaultReps += 1
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 36, height: 36)
                                .background(Theme.Colors.surfaceElevated)
                                .cornerRadius(Theme.Radius.small)
                        }
                    }
                    .foregroundColor(Theme.Colors.textPrimary)
                }
                .padding(Theme.Spacing.md)
                .cardStyle()
            }

            // Weight increment
            HStack {
                Text("Weight increment")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)

                Spacer()

                Picker("", selection: $weightIncrement) {
                    Text("2.5 lbs").tag(2.5)
                    Text("5 lbs").tag(5.0)
                    Text("10 lbs").tag(10.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
    }

    // MARK: - Notes Input
    private var notesInput: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("NOTES (OPTIONAL)")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            TextField("Form cues, tips, etc.", text: $notes, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .lineLimit(3...6)
                .padding(Theme.Spacing.md)
                .cardStyle()
        }
    }

    // MARK: - Save
    private func saveExercise() {
        let exercise = Exercise(
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            notes: notes,
            defaultWeight: defaultWeight,
            defaultReps: defaultReps,
            weightIncrement: weightIncrement
        )

        viewModel.addExercise(exercise)
        dismiss()
    }
}

#Preview {
    NewExerciseSheet()
        .environment(WorkoutViewModel())
        .preferredColorScheme(.dark)
}
