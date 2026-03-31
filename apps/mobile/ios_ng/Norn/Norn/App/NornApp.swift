//
//  NornApp.swift
//  Norn
//
//  Created by Camlost 施 on 2026/3/18.
//

import SwiftUI

@main
struct NornApp: App {
    @State private var store: NornAppStore

    init() {
        let taskRepository = TaskFileRepository()
        let taskPoolOrganizationRepository = TaskPoolOrganizationFileRepository()
        let syncSettingsRepository = UserDefaultsSyncSettingsRepository()
        let syncClient = HTTPTaskSyncClient()

        _store = State(initialValue: NornAppStore(
            loadTasksUseCase: LoadTasksUseCase(repository: taskRepository),
            loadTaskPoolOrganizationUseCase: LoadTaskPoolOrganizationUseCase(repository: taskPoolOrganizationRepository),
            saveTaskPoolOrganizationUseCase: SaveTaskPoolOrganizationUseCase(repository: taskPoolOrganizationRepository),
            quickAddTaskUseCase: QuickAddTaskUseCase(repository: taskRepository),
            saveTaskDraftUseCase: SaveTaskDraftUseCase(repository: taskRepository),
            saveTaskSequenceUseCase: SaveTaskSequenceUseCase(repository: taskRepository),
            reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase(repository: taskRepository),
            toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: taskRepository),
            updateTaskStatusUseCase: UpdateTaskStatusUseCase(repository: taskRepository),
            appendTaskStepUseCase: AppendTaskStepUseCase(repository: taskRepository),
            completeTaskStepUseCase: CompleteTaskStepUseCase(repository: taskRepository),
            archiveTaskUseCase: ArchiveTaskUseCase(repository: taskRepository),
            saveSyncSettingsUseCase: SaveSyncSettingsUseCase(repository: syncSettingsRepository),
            syncTasksUseCase: SyncTasksUseCase(
                taskRepository: taskRepository,
                taskPoolOrganizationRepository: taskPoolOrganizationRepository,
                client: syncClient
            ),
            syncSettingsRepository: syncSettingsRepository
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
