//
//  ExerciseProgressChart.swift
//  Buff Stuff
//
//  Per-exercise strength progress chart with exercise picker
//

import SwiftUI
import Charts

struct ExerciseProgressChart: View {
    @Environment(WorkoutViewModel.self) var viewModel
    let period: ProgressTimePeriod
    @State private var selectedExerciseId: UUID?

    private var exercisesWithHistory: [Exercise] {
        viewModel.exercisesWithHistory()
    }

    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else { return exercisesWithHistory.first }
        return exercisesWithHistory.first { $0.id == id }
    }

    private var dataPoints: [(date: Date, weight: Double)] {
        guard let exercise = selectedExercise else { return [] }
        return viewModel.exerciseProgressDataPoints(exerciseId: exercise.id, in: period)
    }

    private var hasEnoughData: Bool {
        dataPoints.count >= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header with exercise picker
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(Theme.Colors.accent)

                Text("STRENGTH PROGRESS")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Spacer()

                // Exercise Picker
                if !exercisesWithHistory.isEmpty {
                    Menu {
                        ForEach(exercisesWithHistory) { exercise in
                            Button {
                                selectedExerciseId = exercise.id
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                    if selectedExercise?.id == exercise.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(selectedExercise?.name ?? "Select")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textMuted)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.surfaceElevated)
                        .cornerRadius(Theme.Radius.small)
                    }
                }
            }

            if exercisesWithHistory.isEmpty {
                noExercisesState
            } else if hasEnoughData {
                Chart(dataPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(selectedExercise?.muscleGroup.color ?? Theme.Colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .foregroundStyle(selectedExercise?.muscleGroup.color ?? Theme.Colors.accent)
                    .symbolSize(40)
                    .annotation(position: .top) {
                        Text(formatWeight(point.weight))
                            .font(Theme.Typography.captionSmall)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
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
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Theme.Colors.surfaceElevated)
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(Int(weight))")
                                    .font(Theme.Typography.captionSmall)
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                needMoreDataState
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Empty States
    private var noExercisesState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "dumbbell")
                .font(.title2)
                .foregroundColor(Theme.Colors.textMuted)

            Text("No exercise data yet")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private var needMoreDataState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(Theme.Colors.textMuted)

            Text("Need 2+ sessions to show progress")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    // MARK: - Formatting
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) lbs"
        }
        return String(format: "%.1f lbs", weight)
    }
}

#Preview {
    ExerciseProgressChart(period: .month)
        .background(Theme.Colors.background)
        .environment(WorkoutViewModel())
}
