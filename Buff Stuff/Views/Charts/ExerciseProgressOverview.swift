//
//  ExerciseProgressOverview.swift
//  Buff Stuff
//
//  Progressive overload dashboard showing all exercises with progress status
//

import SwiftUI
import Charts

struct ExerciseProgressOverview: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let period: ProgressTimePeriod
    var muscleGroupFilter: Set<MuscleGroup> = []
    @State private var selectedProgress: ExerciseProgress?
    @State private var showAllExercises: Bool = false

    private let defaultDisplayCount = 5

    private var progressData: [ExerciseProgress] {
        let allProgress = viewModel.allExerciseProgress(in: period)
        guard !muscleGroupFilter.isEmpty else { return allProgress }
        return allProgress.filter { muscleGroupFilter.contains($0.exercise.muscleGroup) }
    }

    private var displayedProgress: [ExerciseProgress] {
        if showAllExercises || progressData.count <= defaultDisplayCount {
            return progressData
        }
        return Array(progressData.prefix(defaultDisplayCount))
    }

    private var hasMoreExercises: Bool {
        progressData.count > defaultDisplayCount
    }

    private var hiddenCount: Int {
        progressData.count - defaultDisplayCount
    }

    private var hasData: Bool {
        !progressData.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Theme.Colors.accent)

                Text("PROGRESSIVE OVERLOAD")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Spacer()

                if hasData {
                    progressSummary
                }
            }

            if hasData {
                VStack(spacing: 0) {
                    ForEach(displayedProgress) { progress in
                        VStack(spacing: 0) {
                            ExerciseProgressRow(
                                progress: progress,
                                onTap: {
                                    selectedProgress = progress
                                    triggerHaptic()
                                }
                            )

                            // Divider (except last in displayed list)
                            if progress.id != displayedProgress.last?.id {
                                Divider()
                                    .background(Theme.Colors.surfaceElevated)
                            }
                        }
                    }
                }

                // Show more/less button
                if hasMoreExercises {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllExercises.toggle()
                        }
                        triggerHaptic()
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(showAllExercises ? "Show less" : "Show all \(progressData.count) exercises")
                                .font(Theme.Typography.caption)
                            Image(systemName: showAllExercises ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.sm)
                    }
                }

                // Hint text
                Text("Tap exercise to see progress chart")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xs)
            } else {
                emptyState
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
        .sheet(item: $selectedProgress) { progress in
            ExerciseProgressSheet(
                exercise: progress.exercise,
                progress: progress,
                period: period
            )
            .environment(viewModel)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.Colors.surface)
        }
    }

    // MARK: - Progress Summary
    private var progressSummary: some View {
        let progressingCount = progressData.filter { $0.status == .progressing }.count
        let totalCount = progressData.count

        return HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "arrow.up")
                .font(.caption2)
                .foregroundColor(Theme.Colors.success)

            Text("\(progressingCount)/\(totalCount)")
                .font(Theme.Typography.mono(12))
                .foregroundColor(Theme.Colors.textPrimary)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(Theme.Colors.textMuted)

            Text("No exercise data yet")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            Text("Complete some workouts to track progress")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Exercise Progress Row
struct ExerciseProgressRow: View {
    let progress: ExerciseProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                // Status indicator
                Image(systemName: progress.status.icon)
                    .font(.caption)
                    .foregroundColor(progress.status.color)
                    .frame(width: 16)

                // Exercise name
                Text(progress.exercise.name)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Percent change or session count for new exercises
                if progress.status != .newExercise {
                    Text(formatPercent(progress.percentChange))
                        .font(Theme.Typography.mono(12))
                        .foregroundColor(progress.status.color)
                } else {
                    Text("\(progress.dataPoints) sessions")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                }

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.Colors.textMuted)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatPercent(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(round(percent)))%"
    }
}

#Preview {
    ScrollView {
        ExerciseProgressOverview(period: .month)
            .padding()
    }
    .background(Theme.Colors.background)
    .environment(WorkoutViewModel())
}
