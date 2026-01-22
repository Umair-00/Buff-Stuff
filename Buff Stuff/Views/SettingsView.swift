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
    @State private var cloudKitManager = CloudKitManager.shared
    @State private var syncEngine = SyncEngine.shared
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

    // Feedback state
    @State private var feedbackText: String = ""
    @FocusState private var isFeedbackFocused: Bool

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    header

                    // iCloud Sync Section
                    iCloudSyncSection

                    // HealthKit Section
                    healthKitSection

                    // Data Backup Section
                    dataBackupSection

                    // Feedback Section
                    feedbackSection

                    // App Version
                    appVersionSection
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

    // MARK: - iCloud Sync Section
    private var iCloudSyncSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
                Text("iCloud Sync")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            VStack(spacing: Theme.Spacing.sm) {
                // Sync toggle
                iCloudToggleRow

                // Status indicator
                if cloudKitManager.iCloudSyncEnabled {
                    iCloudStatusRow
                }

                // Sync Now button (when enabled)
                if cloudKitManager.iCloudSyncEnabled && cloudKitManager.isAvailable {
                    iCloudSyncButton
                }

                // Info text
                iCloudInfoRow
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
    }

    private var iCloudToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Sync Data")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)

                Text("Sync exercises and workouts across devices")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { cloudKitManager.iCloudSyncEnabled },
                set: { newValue in
                    if newValue {
                        enableiCloudSync()
                    } else {
                        cloudKitManager.iCloudSyncEnabled = false
                    }
                }
            ))
            .tint(Theme.Colors.accent)
        }
    }

    private var iCloudStatusRow: some View {
        HStack {
            switch syncEngine.syncStatus {
            case .idle:
                if cloudKitManager.isAvailable {
                    Label(syncEngine.statusMessage, systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.success)
                } else {
                    Label("iCloud unavailable", systemImage: "xmark.circle.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.danger)
                }
            case .syncing:
                HStack(spacing: Theme.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textMuted)
                }
            case .error:
                Label(syncEngine.lastError ?? "Sync error", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.warning)
            case .offline:
                Label("Offline - will sync when connected", systemImage: "wifi.slash")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textMuted)
            }

            Spacer()

            // Pending changes indicator
            if syncEngine.hasPendingChanges {
                Text("\(syncEngine.pendingChangeCount) pending")
                    .font(Theme.Typography.captionSmall)
                    .foregroundColor(Theme.Colors.warning)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var iCloudSyncButton: some View {
        Button {
            Task {
                await workoutViewModel.triggerSync()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Sync Now")
                Spacer()
                if syncEngine.syncStatus == .syncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .font(Theme.Typography.body)
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surfaceElevated)
            .cornerRadius(Theme.Radius.medium)
        }
        .disabled(syncEngine.syncStatus == .syncing)
        .padding(.top, Theme.Spacing.xs)
    }

    private var iCloudInfoRow: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundColor(Theme.Colors.textMuted)

            Text("Uses your iCloud account - no sign-in required")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)

            Spacer()
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func enableiCloudSync() {
        Task {
            await cloudKitManager.checkAccountStatus()
            if cloudKitManager.isAvailable {
                cloudKitManager.iCloudSyncEnabled = true
                triggerHaptic(.success)

                // Perform initial migration if needed
                await workoutViewModel.performInitialMigrationIfNeeded()

                // Setup subscription and sync
                await syncEngine.setupSubscription()
                await workoutViewModel.triggerSync()
            } else {
                authErrorMessage = "Please sign in to iCloud in Settings to enable sync"
                showingAuthError = true
            }
        }
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

    // MARK: - Feedback Section
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(Theme.Colors.accent)
                Text("Send Feedback")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
            }

            // Input field
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Bug report, feature idea...", text: $feedbackText)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .focused($isFeedbackFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendFeedback()
                    }

                Button {
                    sendFeedback()
                } label: {
                    if notesViewModel.isSending {
                        ProgressView()
                            .tint(Theme.Colors.background)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(feedbackText.isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
                            .frame(width: 44, height: 44)
                    }
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || notesViewModel.isSending)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surfaceElevated)
            .cornerRadius(Theme.Radius.medium)

            Text("Feedback is sent directly to the developer")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .alert("Feedback Sent!", isPresented: Binding(
            get: { notesViewModel.showSuccess },
            set: { notesViewModel.showSuccess = $0 }
        )) {
            Button("OK") {
                notesViewModel.showSuccess = false
            }
        } message: {
            Text("Thanks! We'll review your feedback soon.")
        }
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notesViewModel.sendFeedback(trimmed)
        feedbackText = ""
        isFeedbackFocused = false
    }

    // MARK: - App Version Section
    private var appVersionSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("BUFF STUFF")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textMuted)
                .tracking(1)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(Theme.Typography.captionSmall)
                .foregroundColor(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.lg)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
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
