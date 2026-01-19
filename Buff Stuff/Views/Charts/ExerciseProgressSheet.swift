//
//  ExerciseProgressSheet.swift
//  Buff Stuff
//
//  Full-screen exercise progress detail view with spacious charts
//

import SwiftUI
import Charts

struct ExerciseProgressSheet: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss
    let exercise: Exercise
    let progress: ExerciseProgress
    let period: ProgressTimePeriod

    @State private var selectedMetric: ChartMetric = .weight

    enum ChartMetric: String, CaseIterable {
        case weight = "WEIGHT"
        case reps = "REPS"
        case volume = "VOLUME"
    }

    private var dataPoints: [(date: Date, weight: Double, reps: Int, volume: Double, topWeight: Double)] {
        viewModel.exerciseProgressDataPointsFull(exerciseId: exercise.id, in: period)
    }

    private var hasEnoughData: Bool {
        dataPoints.count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Status Hero
                        statusHero

                        // Metric Picker
                        metricPicker

                        // Main Chart
                        if hasEnoughData {
                            mainChart
                        } else {
                            needMoreDataState
                        }

                        // Stats Grid
                        statsGrid

                        // Recent Sessions
                        if !dataPoints.isEmpty {
                            recentSessions
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle(exercise.name)
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

    // MARK: - Status Hero
    private var statusHero: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(progress.status.color.opacity(0.15))
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(progress.status.color.opacity(0.3), lineWidth: 2)
                    .frame(width: 72, height: 72)

                Image(systemName: progress.status.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(progress.status.color)
            }

            // Status Text
            VStack(spacing: Theme.Spacing.xs) {
                Text(progress.status.displayName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(progress.status.color)

                if progress.status != .newExercise {
                    Text(formatPercent(progress.percentChange))
                        .font(Theme.Typography.displaySmall(28))
                        .foregroundColor(progress.status.color)
                } else {
                    Text("\(progress.dataPoints) sessions logged")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }

            // Muscle Group Tag
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(exercise.muscleGroup.color)
                    .frame(width: 8, height: 8)

                Text(exercise.muscleGroup.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Radius.full)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .cardStyle()
    }

    // MARK: - Metric Picker
    private var metricPicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ChartMetric.allCases, id: \.self) { metric in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMetric = metric
                    }
                    triggerHaptic()
                } label: {
                    Text(metric.rawValue)
                        .font(Theme.Typography.caption)
                        .fontWeight(selectedMetric == metric ? .bold : .medium)
                        .foregroundColor(selectedMetric == metric ? Theme.Colors.background : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(selectedMetric == metric ? exercise.muscleGroup.color : Theme.Colors.surface)
                        .cornerRadius(Theme.Radius.small)
                }
            }
        }
    }

    // MARK: - Main Chart
    private var mainChart: some View {
        let yRange = calculateYAxisRange()

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Chart Header
            HStack {
                Text(chartTitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .tracking(1)

                Spacer()

                if let latest = dataPoints.last {
                    Text(formatChartValue(for: latest))
                        .font(Theme.Typography.mono(16))
                        .foregroundColor(Theme.Colors.textPrimary)
                }
            }

            // Chart
            Chart(dataPoints, id: \.date) { point in
                // Area fill
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", chartValue(for: point))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [exercise.muscleGroup.color.opacity(0.3), exercise.muscleGroup.color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", chartValue(for: point))
                )
                .foregroundStyle(exercise.muscleGroup.color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Points
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", chartValue(for: point))
                )
                .foregroundStyle(exercise.muscleGroup.color)
                .symbolSize(50)
            }
            .chartYScale(domain: yRange.min...yRange.max)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.Colors.surfaceElevated)
                    AxisValueLabel()
                        .font(Theme.Typography.captionSmall)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.Colors.surfaceElevated)
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text(formatAxisValue(val))
                                .font(Theme.Typography.captionSmall)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                    }
                }
            }
            .frame(height: 240)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        let stats = calculateStats()

        return VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                StatBox(
                    value: formatWeight(stats.currentWeight),
                    label: "CURRENT",
                    color: exercise.muscleGroup.color
                )

                StatBox(
                    value: formatWeight(stats.maxWeight),
                    label: "BEST",
                    color: Theme.Colors.accent
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                StatBox(
                    value: "\(stats.avgReps)",
                    label: "AVG REPS",
                    color: Theme.Colors.textPrimary
                )

                StatBox(
                    value: "\(dataPoints.count)",
                    label: "SESSIONS",
                    color: Theme.Colors.textSecondary
                )
            }
        }
    }

    // MARK: - Recent Sessions
    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("RECENT SESSIONS")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 0) {
                ForEach(Array(dataPoints.suffix(5).reversed().enumerated()), id: \.element.date) { index, point in
                    HStack {
                        Text(formatSessionDate(point.date))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .frame(width: 80, alignment: .leading)

                        Spacer()

                        HStack(spacing: Theme.Spacing.md) {
                            // Weight
                            HStack(spacing: Theme.Spacing.xs) {
                                Text(formatWeight(point.weight))
                                    .font(Theme.Typography.mono(14))
                                    .foregroundColor(Theme.Colors.textPrimary)
                                Text("lbs")
                                    .font(Theme.Typography.captionSmall)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }

                            Text("×")
                                .foregroundColor(Theme.Colors.textMuted)

                            // Reps
                            HStack(spacing: Theme.Spacing.xs) {
                                Text("\(point.reps)")
                                    .font(Theme.Typography.mono(14))
                                    .foregroundColor(exercise.muscleGroup.color)
                                Text("reps")
                                    .font(Theme.Typography.captionSmall)
                                    .foregroundColor(Theme.Colors.textMuted)
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)

                    if index < min(4, dataPoints.count - 1) {
                        Divider()
                            .background(Theme.Colors.surfaceElevated)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .cardStyle(elevated: true)
        }
    }

    // MARK: - Need More Data State
    private var needMoreDataState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.textMuted)

            Text("Need 2+ sessions for chart")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            Text("Keep logging to see your progress")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .cardStyle()
    }

    // MARK: - Helpers
    private var chartTitle: String {
        switch selectedMetric {
        case .weight: return "TOP WEIGHT"
        case .reps: return "TOP SET REPS"
        case .volume: return "TOP SET VOLUME"
        }
    }

    private func chartValue(for point: (date: Date, weight: Double, reps: Int, volume: Double, topWeight: Double)) -> Double {
        switch selectedMetric {
        case .weight: return point.topWeight  // Use heaviest weight lifted, not top volume set weight
        case .reps: return Double(point.reps)
        case .volume: return point.volume
        }
    }

    /// Calculates a dynamic Y-axis range based on the data
    /// Adds padding around min/max for better readability
    private func calculateYAxisRange() -> (min: Double, max: Double) {
        let values = dataPoints.map { chartValue(for: $0) }

        guard let minVal = values.min(), let maxVal = values.max() else {
            return (0, 100)
        }

        // If all values are the same, create a range around that value
        if minVal == maxVal {
            let padding = max(minVal * 0.1, 5) // At least 5 units or 10% padding
            return (max(0, minVal - padding), maxVal + padding)
        }

        let range = maxVal - minVal

        // Add 15% padding above and below for breathing room
        let padding = range * 0.15

        // Calculate bounds, but don't go below 0 for weight/reps/volume
        let lowerBound = max(0, minVal - padding)
        let upperBound = maxVal + padding

        // Round to nice numbers based on the metric
        switch selectedMetric {
        case .weight:
            // Round to nearest 5 lbs
            let roundedLower = floor(lowerBound / 5) * 5
            let roundedUpper = ceil(upperBound / 5) * 5
            return (roundedLower, roundedUpper)

        case .reps:
            // Round to nearest whole number
            let roundedLower = floor(lowerBound)
            let roundedUpper = ceil(upperBound)
            return (roundedLower, roundedUpper)

        case .volume:
            // Round to nearest 50 or 100 depending on scale
            let step: Double = range > 500 ? 100 : 50
            let roundedLower = floor(lowerBound / step) * step
            let roundedUpper = ceil(upperBound / step) * step
            return (roundedLower, roundedUpper)
        }
    }

    private func formatChartValue(for point: (date: Date, weight: Double, reps: Int, volume: Double, topWeight: Double)) -> String {
        switch selectedMetric {
        case .weight: return "\(formatWeight(point.topWeight)) lbs"  // Use heaviest weight
        case .reps: return "\(point.reps) reps"
        case .volume: return "\(formatVolume(point.volume)) lbs"
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        switch selectedMetric {
        case .weight: return "\(Int(value))"
        case .reps: return "\(Int(value))"
        case .volume:
            if value >= 1000 {
                return String(format: "%.0fk", value / 1000)
            }
            return "\(Int(value))"
        }
    }

    private func calculateStats() -> (currentWeight: Double, maxWeight: Double, avgReps: Int) {
        guard !dataPoints.isEmpty else {
            return (0, 0, 0)
        }

        let currentWeight = dataPoints.last?.topWeight ?? 0  // Heaviest weight from most recent session
        let maxWeight = dataPoints.map { $0.topWeight }.max() ?? 0  // All-time heaviest weight
        let avgReps = dataPoints.isEmpty ? 0 : dataPoints.map { $0.reps }.reduce(0, +) / dataPoints.count

        return (currentWeight, maxWeight, avgReps)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }

    private func formatPercent(_ percent: Double) -> String {
        let sign = percent >= 0 ? "+" : ""
        return "\(sign)\(Int(round(percent)))%"
    }

    private func formatSessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Progress Status Extension
extension ProgressStatus {
    var displayName: String {
        switch self {
        case .progressing: return "PROGRESSING"
        case .plateau: return "PLATEAU"
        case .declining: return "DECLINING"
        case .newExercise: return "NEW EXERCISE"
        }
    }
}

#Preview {
    let exercise = Exercise(
        name: "Bench Press",
        muscleGroup: .chest,
        equipment: .barbell,
        defaultWeight: 135,
        defaultReps: 8
    )

    let progress = ExerciseProgress(
        id: exercise.id,
        exercise: exercise,
        status: .progressing,
        baselineVolume: 1000,
        recentVolume: 1100,
        percentChange: 10,
        recentWeight: 145,
        recentReps: 8,
        dataPoints: 6
    )

    return ExerciseProgressSheet(
        exercise: exercise,
        progress: progress,
        period: .month
    )
    .environment(WorkoutViewModel())
}
