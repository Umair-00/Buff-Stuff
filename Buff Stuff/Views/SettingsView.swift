//
//  SettingsView.swift
//  Buff Stuff
//
//  App settings including HealthKit integration and Notes
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(NotesViewModel.self) var notesViewModel
    @Environment(WorkoutViewModel.self) var workoutViewModel
    @State private var healthKitManager = HealthKitManager.shared
    @State private var showingAuthError: Bool = false
    @State private var authErrorMessage: String = ""

    // Export/Import state
    @State private var showingExporter: Bool = false
    @State private var showingImporter: Bool = false
    @State private var exportData: Data?
    @State private var showingImportSuccess: Bool = false
    @State private var showingImportError: Bool = false
    @State private var importErrorMessage: String = ""
    @State private var importedCounts: (exercises: Int, workouts: Int) = (0, 0)

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    // HealthKit Section
                    healthKitSection

                    // Data Backup Section
                    dataBackupSection

                    // Notes Section
                    notesSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, 120)
            }
        }
        .alert("HealthKit Error", isPresented: $showingAuthError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage)
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Imported \(importedCounts.exercises) exercises and \(importedCounts.workouts) workouts.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportData.map { JSONBackupDocument(data: $0) },
            contentType: .json,
            defaultFilename: "buff_stuff_backup.json"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ Exported to: \(url)")
                triggerHaptic(.success)
            case .failure(let error):
                print("❌ Export failed: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("APP")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .tracking(1)

                Text("SETTINGS")
                    .font(Theme.Typography.displaySmall())
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - HealthKit Section
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Apple Health")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                // Sync toggle
                healthKitToggleRow

                // Status indicator
                if healthKitManager.isHealthKitSyncEnabled {
                    healthKitStatusRow
                }

                // Info text
                healthKitInfoRow
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
    }

    private var healthKitToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Sync Workouts")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Save completed workouts to Health")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { healthKitManager.isHealthKitSyncEnabled },
                set: { newValue in
                    if newValue {
                        enableHealthKit()
                    } else {
                        healthKitManager.isHealthKitSyncEnabled = false
                    }
                }
            ))
            .tint(Theme.Colors.accent)
        }
    }

    private var healthKitStatusRow: some View {
        HStack {
            if !healthKitManager.isAvailable {
                Label("HealthKit not available", systemImage: "xmark.circle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.danger)
            } else if healthKitManager.isAuthorized {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.success)
            } else {
                Label("Authorization required", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.warning)

                Spacer()

                Button("Authorize") {
                    enableHealthKit()
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accent)
            }

            Spacer()
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var healthKitInfoRow: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(Theme.Colors.textMuted)

            Text("Workouts sync to Activity rings as exercise minutes")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Data Backup Section
    private var dataBackupSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(Theme.Colors.accent)
                Text("Data Backup")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                // Export button
                Button {
                    exportBackup()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Data")
                        Spacer()
                        Text("\(workoutViewModel.workouts.count) workouts")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surfaceElevated)
                    .cornerRadius(Theme.Radius.medium)
                }

                // Import button
                Button {
                    showingImporter = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.textMuted)
                    }
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.surfaceElevated)
                    .cornerRadius(Theme.Radius.medium)
                }

                // Info text
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.Colors.textMuted)
                    Text("Export saves all exercises and workout history to a file")
                        .font(Theme.Typography.captionSmall)
                        .foregroundColor(Theme.Colors.textMuted)
                    Spacer()
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        NotesContentView()
    }

    // MARK: - Actions
    private func exportBackup() {
        do {
            exportData = try workoutViewModel.exportData()
            showingExporter = true
        } catch {
            print("❌ Export failed: \(error)")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Couldn't access the file"
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                try workoutViewModel.importData(from: data)
                importedCounts = (workoutViewModel.exercises.count, workoutViewModel.workouts.count)
                showingImportSuccess = true
                triggerHaptic(.success)
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }

        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingImportError = true
        }
    }

    private func enableHealthKit() {
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                if healthKitManager.isAuthorized {
                    healthKitManager.isHealthKitSyncEnabled = true
                    triggerHaptic(.success)
                }
            } catch {
                authErrorMessage = error.localizedDescription
                showingAuthError = true
                healthKitManager.isHealthKitSyncEnabled = false
            }
        }
    }

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// MARK: - Notes Content View (Embedded Notes Section)
struct NotesContentView: View {
    @Environment(NotesViewModel.self) var viewModel
    @State private var newNote: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(Theme.Colors.accent)
                Text("Change Requests")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)

                Spacer()

                if !viewModel.changeRequests.isEmpty {
                    Text("\(viewModel.changeRequests.count)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            }

            // Input field
            inputSection

            // Notes list
            if viewModel.changeRequests.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
    }

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

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("No change requests")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)

            Text("Add ideas and improvements here")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var notesList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(viewModel.changeRequests) { request in
                SettingsNoteRow(request: request)
            }
        }
    }

    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addChangeRequest(trimmed)
        newNote = ""
        isInputFocused = false
    }
}

// MARK: - Settings Note Row
struct SettingsNoteRow: View {
    @Environment(NotesViewModel.self) var viewModel
    let request: ChangeRequest

    var body: some View {
        HStack(alignment: .top) {
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

// MARK: - JSON Backup Document
struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SettingsView()
        .environment(NotesViewModel())
        .environment(WorkoutViewModel())
}
