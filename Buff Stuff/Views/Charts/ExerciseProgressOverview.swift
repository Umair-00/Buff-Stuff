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
    @State private var expandedExerciseId: UUID?

    private var progressData: [ExerciseProgress] {
        viewModel.allExerciseProgress(in: period)
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
                    ForEach(progressData) { progress in
                        VStack(spacing: 0) {
                            ExerciseProgressRow(
                                progress: progress,
                                isExpanded: expandedExerciseId == progress.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedExerciseId == progress.id {
                                            expandedExerciseId = nil
                                        } else {
                                            expandedExerciseId = progress.id
                                        }
                                    }
                                    triggerHaptic()
                                }
                            )

                            // Expanded chart view
                            if expandedExerciseId == progress.id {
                                expandedChart(for: progress)
                            }

                            // Divider (except last)
                            if progress.id != progressData.last?.id {
                                Divider()
                                    .background(Theme.Colors.surfaceElevated)
                            }
                        }
                    }
                }

                // Hint text
                Text("Tap exercise to see detailed chart")
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

    // MARK: - Expanded Chart
    private func expandedChart(for progress: ExerciseProgress) -> some View {
        let dataPoints = viewModel.exerciseProgressDataPointsFull(
            exerciseId: progress.exercise.id,
            in: period
        )
        let muscleColor = progress.exercise.muscleGroup.color
        let repsColor = muscleColor.opacity(0.5)

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if dataPoints.count >= 2 {
                // Weight chart
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("WEIGHT")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(0.5)

                    Chart(dataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(muscleColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight)
                        )
                        .foregroundStyle(muscleColor)
                        .symbolSize(30)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Theme.Colors.surfaceElevated)
                            AxisValueLabel()
                                .font(Theme.Typography.captionSmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Theme.Colors.surfaceElevated)
                            AxisValueLabel {
                                if let weight = value.as(Double.self) {
                                    Text("\(Int(weight)) lbs")
                                        .font(Theme.Typography.captionSmall)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                }

                // Reps chart
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("REPS")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                        .tracking(0.5)

                    Chart(dataPoints, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Reps", point.reps)
                        )
                        .foregroundStyle(repsColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Reps", point.reps)
                        )
                        .foregroundStyle(repsColor)
                        .symbolSize(30)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Theme.Colors.surfaceElevated)
                            AxisValueLabel()
                                .font(Theme.Typography.captionSmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Theme.Colors.surfaceElevated)
                            AxisValueLabel {
                                if let reps = value.as(Int.self) {
                                    Text("\(reps)")
                                        .font(Theme.Typography.captionSmall)
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }
                        }
                    }
                    .frame(height: 80)
                }
            } else {
                Text("Need 2+ sessions for chart")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 60)
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(Theme.Colors.surfaceElevated.opacity(0.5))
        .transition(.opacity.combined(with: .move(edge: .top)))
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
    let isExpanded: Bool
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

                // Expand indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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
