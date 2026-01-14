//
//  ExercisePickerSheet.swift
//  Buff Stuff
//
//  Quick exercise selection for logging
//

import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedGroup: MuscleGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Filter chips
                    filterChips

                    // Exercise list
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            // Add new exercise button
                            Button {
                                viewModel.showingNewExercise = true
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Theme.Colors.accent)

                                    Text("Create New Exercise")
                                        .foregroundColor(Theme.Colors.accent)

                                    Spacer()
                                }
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.md)
                                .cardStyle(elevated: true)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.md)

                            // Exercises by group
                            ForEach(filteredGroups, id: \.0) { group, exercises in
                                ExerciseGroupSection(
                                    group: group,
                                    exercises: exercises,
                                    onSelect: { exercise in
                                        viewModel.prepareQuickLog(for: exercise)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.bottom, Theme.Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textMuted)

            TextField("Search exercises", text: $searchText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Radius.medium)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    label: "All",
                    isSelected: selectedGroup == nil
                ) {
                    selectedGroup = nil
                }

                ForEach(MuscleGroup.allCases) { group in
                    FilterChip(
                        label: group.rawValue,
                        color: group.color,
                        isSelected: selectedGroup == group
                    ) {
                        selectedGroup = selectedGroup == group ? nil : group
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    // MARK: - Filtered Groups
    private var filteredGroups: [(MuscleGroup, [Exercise])] {
        let groups = viewModel.exercisesByGroup()

        return groups.compactMap { group, exercises in
            // Filter by selected group
            if let selected = selectedGroup, selected != group {
                return nil
            }

            // Filter by search
            let filtered = exercises.filter { exercise in
                searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            }

            return filtered.isEmpty ? nil : (group, filtered)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    var color: Color = Theme.Colors.accent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(isSelected ? Theme.Colors.background : Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isSelected ? color : Theme.Colors.surface)
                .cornerRadius(Theme.Radius.full)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Exercise Group Section
struct ExerciseGroupSection: View {
    let group: MuscleGroup
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Group header
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(group.color)
                    .frame(width: 8, height: 8)

                Text(group.rawValue.uppercased())
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
                    .tracking(1)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)

            // Exercises
            ForEach(exercises) { exercise in
                Button {
                    onSelect(exercise)
                } label: {
                    ExercisePickerRow(exercise: exercise)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Exercise Picker Row
struct ExercisePickerRow: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(exercise.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }

            Spacer()

            if exercise.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.warning)
            }

            // Default values hint
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(exercise.defaultWeight)) lbs")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)

                Text("\(exercise.defaultReps) reps")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.leading, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface)
        .cornerRadius(Theme.Radius.medium)
        .padding(.horizontal, Theme.Spacing.md)
    }
}

#Preview {
    ExercisePickerSheet()
        .environment(WorkoutViewModel())
        .preferredColorScheme(.dark)
}
