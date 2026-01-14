//
//  HistoryView.swift
//  Buff Stuff
//
//  Workout history
//

import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @State private var selectedWorkout: Workout?

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    if viewModel.workouts.isEmpty {
                        emptyState
                    } else {
                        // Stats summary
                        statsSummary

                        // Workout list
                        workoutList
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailSheet(workout: workout)
                .environment(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Colors.surface)
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("YOUR PROGRESS")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .tracking(1)

            Text("HISTORY")
                .font(Theme.Typography.displaySmall())
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.surface)
                    .frame(width: 100, height: 100)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.textMuted)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("NO WORKOUTS YET")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Your completed workouts will appear here")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - Stats Summary
    private var statsSummary: some View {
        HStack(spacing: Theme.Spacing.md) {
            SummaryCard(
                value: "\(viewModel.workouts.count)",
                label: "Workouts",
                icon: "flame.fill",
                color: Theme.Colors.accent
            )

            SummaryCard(
                value: "\(totalSets)",
                label: "Total Sets",
                icon: "square.stack.3d.up.fill",
                color: Theme.Colors.textPrimary
            )

            SummaryCard(
                value: formatVolume(totalVolume),
                label: "Volume",
                icon: "scalemass.fill",
                color: Theme.Colors.steel
            )
        }
    }

    private var totalSets: Int {
        viewModel.workouts.reduce(0) { $0 + $1.totalSets }
    }

    private var totalVolume: Double {
        viewModel.workouts.reduce(0) { $0 + $1.totalVolume }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000000 {
            return String(format: "%.1fM", volume / 1000000)
        } else if volume >= 1000 {
            return String(format: "%.0fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    // MARK: - Workout List
    private var workoutList: some View {
        LazyVStack(spacing: Theme.Spacing.sm) {
            ForEach(groupedWorkouts, id: \.0) { section, workouts in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(section)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(1)
                        .padding(.top, Theme.Spacing.md)

                    ForEach(workouts) { workout in
                        WorkoutHistoryCard(workout: workout)
                            .onTapGesture {
                                selectedWorkout = workout
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteWorkout(workout)
                                } label: {
                                    Label("Delete Workout", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private var groupedWorkouts: [(String, [Workout])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.workouts) { workout -> String in
            if calendar.isDateInToday(workout.startedAt) {
                return "TODAY"
            } else if calendar.isDateInYesterday(workout.startedAt) {
                return "YESTERDAY"
            } else if calendar.isDate(workout.startedAt, equalTo: Date(), toGranularity: .weekOfYear) {
                return "THIS WEEK"
            } else if calendar.isDate(workout.startedAt, equalTo: Date(), toGranularity: .month) {
                return "THIS MONTH"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: workout.startedAt).uppercased()
            }
        }

        let order = ["TODAY", "YESTERDAY", "THIS WEEK", "THIS MONTH"]
        return grouped.sorted { a, b in
            let aIndex = order.firstIndex(of: a.key) ?? 100
            let bIndex = order.firstIndex(of: b.key) ?? 100
            if aIndex != bIndex { return aIndex < bIndex }
            return a.key < b.key
        }
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(Theme.Typography.displaySmall(24))
                .foregroundColor(Theme.Colors.textPrimary)

            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

// MARK: - Workout History Card
struct WorkoutHistoryCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(workout.displayName.uppercased())
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.textPrimary)

                    Text("\(workout.dateFormatted) • \(workout.timeFormatted)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            // Muscle group tags
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(workout.muscleGroups.prefix(3), id: \.self) { group in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(group.color)
                            .frame(width: 6, height: 6)

                        Text(group.rawValue)
                            .font(Theme.Typography.captionSmall)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.surfaceElevated)
                    .cornerRadius(Theme.Radius.full)
                }
            }

            // Stats row
            HStack(spacing: Theme.Spacing.lg) {
                Label("\(workout.totalSets) sets", systemImage: "square.stack.fill")
                Label(workout.durationFormatted, systemImage: "clock.fill")
                Label(formatVolume(workout.totalVolume), systemImage: "scalemass.fill")
            }
            .font(Theme.Typography.captionSmall)
            .foregroundColor(Theme.Colors.textMuted)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk lbs", volume / 1000)
        }
        return String(format: "%.0f lbs", volume)
    }
}

// MARK: - Workout Detail Sheet
struct WorkoutDetailSheet: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let workout: Workout
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Header stats
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
                                label: "DURATION",
                                color: Theme.Colors.textSecondary
                            )
                        }
                        .padding(Theme.Spacing.md)
                        .cardStyle(elevated: true)

                        // Exercise entries
                        ForEach(workout.entries) { entry in
                            WorkoutDetailEntry(entry: entry)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle(workout.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.Colors.danger)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
            .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteWorkout(workout)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this workout? This cannot be undone.")
            }
        }
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - Workout Detail Entry
struct WorkoutDetailEntry: View {
    let entry: ExerciseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Exercise name
            HStack {
                Circle()
                    .fill(entry.exercise.muscleGroup.color)
                    .frame(width: 8, height: 8)

                Text(entry.exercise.name.uppercased())
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                Text("\(entry.workingSets.count) sets")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            // Sets
            VStack(spacing: 0) {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text(set.isWarmup ? "W" : "\(index + 1)")
                            .font(Theme.Typography.mono(14))
                            .foregroundColor(set.isWarmup ? Theme.Colors.warning : Theme.Colors.textMuted)
                            .frame(width: 24)

                        Spacer()

                        Text(formatWeight(set.weight))
                            .font(Theme.Typography.mono(16))
                            .foregroundColor(Theme.Colors.textPrimary)

                        Text("lbs")
                            .font(Theme.Typography.captionSmall)
                            .foregroundColor(Theme.Colors.textMuted)

                        Text("×")
                            .foregroundColor(Theme.Colors.textMuted)
                            .padding(.horizontal, Theme.Spacing.sm)

                        Text("\(set.reps)")
                            .font(Theme.Typography.mono(16))
                            .foregroundColor(Theme.Colors.accent)

                        Text("reps")
                            .font(Theme.Typography.captionSmall)
                            .foregroundColor(Theme.Colors.textMuted)

                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surfaceElevated)
            .cornerRadius(Theme.Radius.medium)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

#Preview {
    HistoryView()
        .environment(WorkoutViewModel())
}
