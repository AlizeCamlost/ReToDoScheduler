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
        let syncSettingsRepository = UserDefaultsSyncSettingsRepository()
        let syncClient = HTTPTaskSyncClient()

        _store = State(initialValue: NornAppStore(
            loadTasksUseCase: LoadTasksUseCase(repository: taskRepository),
            quickAddTaskUseCase: QuickAddTaskUseCase(repository: taskRepository),
            saveTaskDraftUseCase: SaveTaskDraftUseCase(repository: taskRepository),
            reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase(repository: taskRepository),
            toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: taskRepository),
            archiveTaskUseCase: ArchiveTaskUseCase(repository: taskRepository),
            saveSyncSettingsUseCase: SaveSyncSettingsUseCase(repository: syncSettingsRepository),
            syncTasksUseCase: SyncTasksUseCase(repository: taskRepository, client: syncClient),
            syncSettingsRepository: syncSettingsRepository
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
