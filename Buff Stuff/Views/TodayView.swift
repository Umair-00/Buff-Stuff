//
//  TodayView.swift
//  Buff Stuff
//
//  Main workout screen - shows active workout and quick logging
//

import SwiftUI

struct TodayView: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @State private var showingFinishConfirm = false

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection

                    if let workout = viewModel.activeWorkout {
                        // Active workout content
                        activeWorkoutHeader(workout)
                        exerciseEntries(workout)
                    } else {
                        // No active workout
                        emptyState
                        recentExercisesSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120) // Space for tab bar
            }
        }
        .confirmationDialog("Finish Workout?", isPresented: $showingFinishConfirm) {
            Button("Finish Workout") {
                viewModel.finishWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let workout = viewModel.activeWorkout {
                Text("\(workout.totalSets) sets logged • \(workout.durationFormatted)")
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(greeting)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)

                Text("BUFF STUFF")
                    .font(Theme.Typography.displaySmall())
                    .foregroundColor(Theme.Colors.textPrimary)
                    .tracking(2)
            }

            Spacer()

            // Date badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(dayOfWeek)
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.accent)

                Text(dayNumber)
                    .font(Theme.Typography.displaySmall(28))
                    .foregroundColor(Theme.Colors.textPrimary)
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "GOOD MORNING"
        case 12..<17: return "GOOD AFTERNOON"
        case 17..<21: return "GOOD EVENING"
        default: return "LATE NIGHT GRIND"
        }
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: Date())
    }

    // MARK: - Active Workout Header
    private func activeWorkoutHeader(_ workout: Workout) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // Stats row
            HStack(spacing: Theme.Spacing.lg) {
                StatBox(
                    value: "\(workout.totalSets)",
                    label: "SETS",
                    color: Theme.Colors.accent
                )

                StatBox(
                    value: formatVolume(workout.totalVolume),
                    label: "VOLUME",
                    color: Theme.Colors.textPrimary
                )

                StatBox(
                    value: workout.durationFormatted,
                    label: "TIME",
                    color: Theme.Colors.textSecondary
                )
            }

            // Finish button
            Button {
                showingFinishConfirm = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("FINISH WORKOUT")
                }
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(Theme.Spacing.md)
        .cardStyle(elevated: true)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    // MARK: - Exercise Entries
    private func exerciseEntries(_ workout: Workout) -> some View {
        LazyVStack(spacing: Theme.Spacing.md) {
            ForEach(workout.entries) { entry in
                ExerciseEntryCard(entry: entry)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentMuted)
                    .frame(width: 100, height: 100)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("NO ACTIVE WORKOUT")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Tap + to start logging sets")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Button {
                viewModel.startWorkout()
            } label: {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("START WORKOUT")
                }
            }
            .buttonStyle(AccentButtonStyle(isLarge: true))
        }
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - Recent Exercises
    private var recentExercisesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("QUICK START")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.recentExercises(limit: 5)) { exercise in
                    QuickStartExerciseRow(exercise: exercise)
                }
            }
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Typography.displaySmall(24))
                .foregroundColor(color)

            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Exercise Entry Card
struct ExerciseEntryCard: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let entry: ExerciseEntry
    @State private var expanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3)) {
                    expanded.toggle()
                }
            } label: {
                HStack {
                    // Muscle group indicator
                    Circle()
                        .fill(entry.exercise.muscleGroup.color)
                        .frame(width: 8, height: 8)

                    Text(entry.exercise.name.uppercased())
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Spacer()

                    Text("\(entry.workingSets.count) sets")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
                .padding(Theme.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            if expanded {
                Divider()
                    .background(Theme.Colors.surfaceElevated)

                // Sets list
                VStack(spacing: 0) {
                    ForEach(entry.sets) { set in
                        SetRow(set: set, exerciseId: entry.exercise.id)
                    }
                }

                // Quick add buttons
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        viewModel.repeatLastSet(for: entry.exercise)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("REPEAT")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.accent)
                    }

                    Spacer()

                    Button {
                        viewModel.prepareQuickLog(for: entry.exercise)
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("ADD SET")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.accent)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.surfaceElevated.opacity(0.5))
            }
        }
        .cardStyle()
    }
}

// MARK: - Set Row
struct SetRow: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let set: WorkoutSet
    let exerciseId: UUID

    var body: some View {
        HStack {
            // Set indicator
            if set.isWarmup {
                Text("W")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.warning)
                    .frame(width: 24)
            } else {
                Text("\(setNumber)")
                    .font(Theme.Typography.mono(14))
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(width: 24)
            }

            Spacer()

            // Weight
            HStack(spacing: Theme.Spacing.xs) {
                Text(formatWeight(set.weight))
                    .font(Theme.Typography.mono(18))
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("lbs")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Text("×")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textMuted)
                .padding(.horizontal, Theme.Spacing.sm)

            // Reps
            Text("\(set.reps)")
                .font(Theme.Typography.mono(18))
                .foregroundColor(Theme.Colors.accent)

            Text("reps")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            Spacer()

            // Delete button
            Button {
                viewModel.deleteSet(set, from: exerciseId)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var setNumber: Int {
        if let workout = viewModel.activeWorkout,
           let entry = workout.entries.first(where: { $0.exercise.id == exerciseId }) {
            return (entry.workingSets.firstIndex(where: { $0.id == set.id }) ?? 0) + 1
        }
        return 1
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Quick Start Exercise Row
struct QuickStartExerciseRow: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise

    var body: some View {
        Button {
            viewModel.prepareQuickLog(for: exercise)
        } label: {
            HStack {
                Circle()
                    .fill(exercise.muscleGroup.color)
                    .frame(width: 6, height: 6)

                Text(exercise.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                if exercise.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.warning)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TodayView()
        .environment(WorkoutViewModel())
}
