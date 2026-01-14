//
//  ExerciseLibraryView.swift
//  Buff Stuff
//
//  Manage custom exercises
//

import SwiftUI

struct ExerciseLibraryView: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @State private var searchText = ""
    @State private var showingNewExercise = false

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    // Search
                    searchBar

                    // Stats
                    statsRow

                    // Exercise list by group
                    ForEach(filteredGroups, id: \.0) { group, exercises in
                        exerciseSection(group: group, exercises: exercises)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            NewExerciseSheet()
                .environment(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Colors.surface)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("YOUR EXERCISES")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Text("LIBRARY")
                    .font(Theme.Typography.displaySmall())
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()

            Button {
                showingNewExercise = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Theme.Colors.background)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.accent)
                    .cornerRadius(Theme.Radius.medium)
            }
        }
        .padding(.top, Theme.Spacing.lg)
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
        .cardStyle()
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            MiniStatCard(
                value: "\(viewModel.exercises.count)",
                label: "Total",
                icon: "dumbbell.fill"
            )

            MiniStatCard(
                value: "\(viewModel.exercises.filter { $0.isFavorite }.count)",
                label: "Favorites",
                icon: "star.fill",
                color: Theme.Colors.warning
            )

            MiniStatCard(
                value: "\(Set(viewModel.exercises.map { $0.muscleGroup }).count)",
                label: "Groups",
                icon: "figure.strengthtraining.traditional"
            )
        }
    }

    // MARK: - Filtered Groups
    private var filteredGroups: [(MuscleGroup, [Exercise])] {
        viewModel.exercisesByGroup().compactMap { group, exercises in
            let filtered = exercises.filter { exercise in
                searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (group, filtered)
        }
    }

    // MARK: - Exercise Section
    private func exerciseSection(group: MuscleGroup, exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Group header
            HStack {
                Image(systemName: group.icon)
                    .font(.caption)
                    .foregroundColor(group.color)

                Text(group.rawValue.uppercased())
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Spacer()

                Text("\(exercises.count)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            // Exercises
            ForEach(exercises) { exercise in
                ExerciseLibraryRow(exercise: exercise)
            }
        }
    }
}

// MARK: - Mini Stat Card
struct MiniStatCard: View {
    let value: String
    let label: String
    let icon: String
    var color: Color = Theme.Colors.accent

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)

                Text(value)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

// MARK: - Exercise Library Row
struct ExerciseLibraryRow: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise
    @State private var showingEdit = false

    var body: some View {
        HStack {
            // Color indicator
            Rectangle()
                .fill(exercise.muscleGroup.color)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(exercise.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                HStack(spacing: Theme.Spacing.md) {
                    Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)

                    Text("\(Int(exercise.defaultWeight)) lbs × \(exercise.defaultReps)")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }

            Spacer()

            // Favorite button
            Button {
                viewModel.toggleFavorite(exercise)
            } label: {
                Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundColor(exercise.isFavorite ? Theme.Colors.warning : Theme.Colors.textMuted)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
        .contextMenu {
            Button {
                viewModel.toggleFavorite(exercise)
            } label: {
                Label(
                    exercise.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: exercise.isFavorite ? "star.slash" : "star"
                )
            }

            Button(role: .destructive) {
                viewModel.deleteExercise(exercise)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ExerciseLibraryView()
        .environment(WorkoutViewModel())
}
