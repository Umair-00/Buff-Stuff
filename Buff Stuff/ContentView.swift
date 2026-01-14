//
//  ContentView.swift
//  Buff Stuff
//
//  Created by Umair Ahmed on 1/13/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = WorkoutViewModel()
    @State private var notesViewModel = NotesViewModel()
    @State private var selectedTab: Tab = .today

    enum Tab {
        case today, exercises, history, notes
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabView(selection: $selectedTab) {
                TodayView()
                    .tag(Tab.today)

                ExerciseLibraryView()
                    .tag(Tab.exercises)

                HistoryView()
                    .tag(Tab.history)

                NotesView()
                    .tag(Tab.notes)
                    .environment(notesViewModel)
            }
            .environment(viewModel)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab, viewModel: viewModel)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showingQuickLog) {
            QuickLogSheet()
                .environment(viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Colors.surface)
        }
        .sheet(isPresented: $viewModel.showingExercisePicker) {
            ExercisePickerSheet()
                .environment(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Colors.surface)
        }
        .sheet(isPresented: $viewModel.showingNewExercise) {
            NewExerciseSheet()
                .environment(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Colors.surface)
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    @Bindable var viewModel: WorkoutViewModel

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "flame.fill",
                label: "Today",
                isSelected: selectedTab == .today
            ) {
                selectedTab = .today
            }

            TabBarButton(
                icon: "dumbbell.fill",
                label: "Exercises",
                isSelected: selectedTab == .exercises
            ) {
                selectedTab = .exercises
            }

            // Center action button
            QuickAddButton {
                viewModel.showingExercisePicker = true
            }
            .offset(y: -20)

            TabBarButton(
                icon: "calendar",
                label: "History",
                isSelected: selectedTab == .history
            ) {
                selectedTab = .history
            }

            TabBarButton(
                icon: "note.text",
                label: "Notes",
                isSelected: selectedTab == .notes
            ) {
                selectedTab = .notes
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xl)
        .background(
            Theme.Colors.surface
                .ignoresSafeArea()
                .shadow(color: .black.opacity(0.5), radius: 20, y: -10)
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textMuted)

                Text(label)
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Quick Add Button (Center FAB)
struct QuickAddButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Glow effect
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.3))
                    .frame(width: 70, height: 70)
                    .blur(radius: 10)

                // Main button
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.background)
                    )
                    .shadow(color: Theme.Colors.accent.opacity(0.5), radius: 10, y: 5)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    ContentView()
}
