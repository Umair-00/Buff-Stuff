//
//  QuickLogSheet.swift
//  Buff Stuff
//
//  Fast set logging interface - optimized for speed
//

import SwiftUI

struct QuickLogSheet: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: Theme.Spacing.md) {
            // Exercise name
            if let exercise = viewModel.selectedExercise {
                HStack {
                    Circle()
                        .fill(exercise.muscleGroup.color)
                        .frame(width: 8, height: 8)

                    Text(exercise.name.uppercased())
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }

                // Smart suggestion
                if let suggestion = viewModel.getSuggestion(for: exercise) {
                    SuggestionBanner(suggestion: suggestion) {
                        if let weight = suggestion.suggestedWeight {
                            viewModel.quickLogWeight = weight
                        }
                    }
                }
            }

            // Weight & Reps input - side by side
            HStack(spacing: Theme.Spacing.md) {
                // Weight
                ValueAdjuster(
                    value: $vm.quickLogWeight,
                    label: "WEIGHT",
                    unit: "lbs",
                    step: viewModel.selectedExercise?.weightIncrement ?? 5,
                    color: Theme.Colors.textPrimary
                )

                // Divider
                Rectangle()
                    .fill(Theme.Colors.surfaceElevated)
                    .frame(width: 1, height: 80)

                // Reps
                ValueAdjuster(
                    value: Binding(
                        get: { Double(viewModel.quickLogReps) },
                        set: { viewModel.quickLogReps = Int($0) }
                    ),
                    label: "REPS",
                    unit: "",
                    step: 1,
                    color: Theme.Colors.accent,
                    isInteger: true
                )
            }
            .padding(.vertical, Theme.Spacing.sm)

            // Quick presets
            if viewModel.selectedExercise != nil {
                quickPresets
            }

            Spacer()

            // Log button
            Button {
                viewModel.logSet()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                        .font(.headline)
                    Text("LOG SET")
                        .font(Theme.Typography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
            }
            .buttonStyle(AccentButtonStyle(isLarge: true))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.lg)
    }

    // MARK: - Quick Presets
    @ViewBuilder
    private var quickPresets: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("QUICK REPS")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: Theme.Spacing.sm) {
                // Common rep schemes
                ForEach([5, 8, 10, 12], id: \.self) { reps in
                    Button {
                        viewModel.quickLogReps = reps
                    } label: {
                        Text("\(reps)")
                            .font(Theme.Typography.mono(14))
                            .foregroundColor(viewModel.quickLogReps == reps ? Theme.Colors.background : Theme.Colors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(viewModel.quickLogReps == reps ? Theme.Colors.accent : Theme.Colors.surfaceElevated)
                            .cornerRadius(Theme.Radius.small)
                    }
                }

                Spacer()

                // Warmup button
                Button {
                    if let ex = viewModel.selectedExercise {
                        viewModel.logSet(for: ex, weight: viewModel.quickLogWeight, reps: viewModel.quickLogReps, isWarmup: true)
                        dismiss()
                    }
                } label: {
                    Text("WARMUP")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.warning)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Theme.Colors.warning.opacity(0.2))
                        .cornerRadius(Theme.Radius.small)
                }
            }
        }
    }
}

// MARK: - Value Adjuster (Compact)
struct ValueAdjuster: View {
    @Binding var value: Double
    let label: String
    let unit: String
    let step: Double
    let color: Color
    var isInteger: Bool = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            HStack(spacing: Theme.Spacing.sm) {
                // Decrease
                AdjusterButton(icon: "minus") {
                    value = max(0, value - step)
                }

                // Value display
                VStack(spacing: 2) {
                    Text(formattedValue)
                        .font(Theme.Typography.displaySmall(32))
                        .foregroundColor(color)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(Theme.Typography.captionSmall)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                }
                .frame(minWidth: 55)

                // Increase
                AdjusterButton(icon: "plus") {
                    value += step
                }
            }
        }
    }

    private var formattedValue: String {
        if isInteger {
            return String(format: "%.0f", value)
        }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Adjuster Button (Compact)
struct AdjusterButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            action()
            triggerHaptic()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.surfaceElevated)
                .cornerRadius(Theme.Radius.small)
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Suggestion Banner
struct SuggestionBanner: View {
    let suggestion: WorkoutSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)

                Text(suggestion.message)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if suggestion.suggestedWeight != nil {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.surfaceElevated.opacity(0.6))
            .cornerRadius(Theme.Radius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .progressiveOverload:
            return Theme.Colors.accent
        case .consistentPerformance:
            return Theme.Colors.success
        case .newExercise:
            return Theme.Colors.textMuted
        }
    }
}

#Preview {
    QuickLogSheet()
        .environment(WorkoutViewModel())
        .preferredColorScheme(.dark)
        .background(Theme.Colors.surface)
}
