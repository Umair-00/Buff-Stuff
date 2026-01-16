//
//  ProgressChartsSection.swift
//  Buff Stuff
//
//  Container for progress charts with time period picker
//

import SwiftUI

struct ProgressChartsSection: View {
    @Environment(WorkoutViewModel.self) var viewModel
    @Binding var selectedPeriod: ProgressTimePeriod
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Time Period Picker
            timePeriodPicker

            // Collapsible Charts
            if isExpanded {
                // Progressive Overload Overview
                ExerciseProgressOverview(period: selectedPeriod)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Time Period Picker
    private var timePeriodPicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ProgressTimePeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                    triggerHaptic()
                } label: {
                    Text(period.rawValue)
                        .font(Theme.Typography.caption)
                        .fontWeight(selectedPeriod == period ? .bold : .medium)
                        .foregroundColor(selectedPeriod == period ? Theme.Colors.background : Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(selectedPeriod == period ? Theme.Colors.accent : Theme.Colors.surface)
                        .cornerRadius(Theme.Radius.small)
                }
            }

            Spacer()

            // Collapse/Expand button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
                triggerHaptic()
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.textMuted)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.surface)
                    .cornerRadius(Theme.Radius.small)
            }
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    ScrollView {
        ProgressChartsSection(selectedPeriod: .constant(.month))
            .padding()
    }
    .background(Theme.Colors.background)
    .environment(WorkoutViewModel())
}
