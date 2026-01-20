//
//  NotesView.swift
//  Buff Stuff
//
//  Send feedback and feature requests
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesViewModel.self) var viewModel
    @State private var feedbackText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    // Feedback form
                    feedbackForm

                    // Info text
                    infoText
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .alert("Feedback Sent!", isPresented: Binding(
            get: { viewModel.showSuccess },
            set: { viewModel.showSuccess = $0 }
        )) {
            Button("OK") {
                viewModel.showSuccess = false
            }
        } message: {
            Text("Thanks for your feedback! We'll review it soon.")
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("SEND US YOUR")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Text("FEEDBACK")
                    .font(Theme.Typography.displaySmall())
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()

            Image(systemName: "paperplane.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.accent)
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Feedback Form
    private var feedbackForm: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Text input
            TextEditor(text: $feedbackText)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($isInputFocused)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.surfaceElevated)
                .cornerRadius(Theme.Radius.medium)
                .overlay(
                    Group {
                        if feedbackText.isEmpty {
                            Text("Describe a bug, feature idea, or improvement...")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textMuted)
                                .padding(Theme.Spacing.md)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )

            // Send button
            Button {
                sendFeedback()
            } label: {
                HStack {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(Theme.Colors.background)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("SEND FEEDBACK")
                            .font(Theme.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
            }
            .buttonStyle(AccentButtonStyle(isLarge: true))
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Info Text
    private var infoText: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "info.circle")
                Text("Your feedback helps us improve Buff Stuff")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.textMuted)

            Text("Bug reports, feature requests, and suggestions are all welcome!")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
    }

    // MARK: - Actions
    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.sendFeedback(trimmed)
        feedbackText = ""
        isInputFocused = false
    }
}

#Preview {
    NotesView()
        .environment(NotesViewModel())
}
