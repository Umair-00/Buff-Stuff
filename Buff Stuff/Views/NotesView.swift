//
//  NotesView.swift
//  Buff Stuff
//
//  Change requests and feature ideas
//

import SwiftUI

struct NotesView: View {
    @Environment(NotesViewModel.self) var viewModel
    @State private var newNote: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    // Input field
                    inputSection

                    // Stats
                    if !viewModel.changeRequests.isEmpty {
                        statsRow
                    }

                    // Notes list
                    if viewModel.changeRequests.isEmpty {
                        emptyState
                    } else {
                        notesList
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("CHANGE REQUESTS")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Text("NOTES")
                    .font(Theme.Typography.displaySmall())
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Input Section
    private var inputSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Add a change request...", text: $newNote)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .focused($isInputFocused)
                .submitLabel(.done)
                .onSubmit {
                    addNote()
                }

            Button {
                addNote()
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Theme.Colors.background)
                    .frame(width: 44, height: 44)
                    .background(newNote.isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
                    .cornerRadius(Theme.Radius.medium)
            }
            .disabled(newNote.isEmpty)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            MiniStatCard(
                value: "\(viewModel.changeRequests.count)",
                label: "Total",
                icon: "note.text"
            )
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.textMuted)

            Text("No change requests yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.textSecondary)

            Text("Add ideas and improvements as you use the app")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - Notes List
    private var notesList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(viewModel.changeRequests) { request in
                NoteRow(request: request)
            }
        }
    }

    // MARK: - Actions
    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addChangeRequest(trimmed)
        newNote = ""
        isInputFocused = false
    }
}

// MARK: - Note Row
struct NoteRow: View {
    @Environment(NotesViewModel.self) var viewModel
    let request: ChangeRequest

    var body: some View {
        HStack(alignment: .top) {
            // Color indicator
            Rectangle()
                .fill(Theme.Colors.accent)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(request.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            // Delete button
            Button {
                viewModel.deleteChangeRequest(request)
            } label: {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(Theme.Colors.danger)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

#Preview {
    NotesView()
        .environment(NotesViewModel())
}
