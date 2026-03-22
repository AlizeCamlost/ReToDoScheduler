import Foundation
import Observation

@MainActor
@Observable
final class NornAppStore {
  var currentTab: AppTab
  var tasks: [Task]
  var quickAddInput: String
  var syncSettings: SyncSettings
  var syncStatus: SyncStatus
  var selectedTaskID: String?
  var taskDraft: TaskDraft?
  var isSyncSettingsPresented: Bool

  @ObservationIgnored private let loadTasksUseCase: LoadTasksUseCase
  @ObservationIgnored private let quickAddTaskUseCase: QuickAddTaskUseCase
  @ObservationIgnored private let saveTaskDraftUseCase: SaveTaskDraftUseCase
  @ObservationIgnored private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase
  @ObservationIgnored private let archiveTaskUseCase: ArchiveTaskUseCase
  @ObservationIgnored private let saveSyncSettingsUseCase: SaveSyncSettingsUseCase
  @ObservationIgnored private let syncTasksUseCase: SyncTasksUseCase
  @ObservationIgnored private let syncSettingsRepository: any SyncSettingsRepositoryProtocol
  @ObservationIgnored private var hasBootstrapped = false

  init(
    currentTab: AppTab = .sequence,
    tasks: [Task] = [],
    quickAddInput: String = "",
    syncSettings: SyncSettings = .empty,
    syncStatus: SyncStatus = .notConfigured,
    selectedTaskID: String? = nil,
    taskDraft: TaskDraft? = nil,
    isSyncSettingsPresented: Bool = false,
    loadTasksUseCase: LoadTasksUseCase,
    quickAddTaskUseCase: QuickAddTaskUseCase,
    saveTaskDraftUseCase: SaveTaskDraftUseCase,
    toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase,
    archiveTaskUseCase: ArchiveTaskUseCase,
    saveSyncSettingsUseCase: SaveSyncSettingsUseCase,
    syncTasksUseCase: SyncTasksUseCase,
    syncSettingsRepository: any SyncSettingsRepositoryProtocol
  ) {
    self.currentTab = currentTab
    self.tasks = tasks
    self.quickAddInput = quickAddInput
    self.syncSettings = syncSettings
    self.syncStatus = syncStatus
    self.selectedTaskID = selectedTaskID
    self.taskDraft = taskDraft
    self.isSyncSettingsPresented = isSyncSettingsPresented
    self.loadTasksUseCase = loadTasksUseCase
    self.quickAddTaskUseCase = quickAddTaskUseCase
    self.saveTaskDraftUseCase = saveTaskDraftUseCase
    self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
    self.archiveTaskUseCase = archiveTaskUseCase
    self.saveSyncSettingsUseCase = saveSyncSettingsUseCase
    self.syncTasksUseCase = syncTasksUseCase
    self.syncSettingsRepository = syncSettingsRepository
  }

  var visibleTasks: [Task] {
    tasks.filter { $0.status != .archived }
  }

  var selectedTask: Task? {
    guard let selectedTaskID else {
      return nil
    }
    return tasks.first { $0.id == selectedTaskID }
  }

  func bootstrap() {
    guard !hasBootstrapped else { return }
    hasBootstrapped = true
    reloadLocalState()
  }

  func refresh() {
    reloadLocalState()
  }

  func submitQuickAdd() {
    quickAddInput = quickAddInput.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func openTaskDetail(taskID: String) {
    selectedTaskID = taskID
  }

  func closeTaskDetail() {
    selectedTaskID = nil
  }

  func openTaskEditor(taskID: String) {
    guard let task = tasks.first(where: { $0.id == taskID }) else { return }
    taskDraft = TaskDraft(task: task)
  }

  func closeTaskEditor() {
    taskDraft = nil
  }

  func openSyncSettings() {
    isSyncSettingsPresented = true
  }

  func closeSyncSettings() {
    isSyncSettingsPresented = false
  }

  private func reloadLocalState() {
    do {
      tasks = try loadTasksUseCase.execute()
    } catch {
      tasks = []
    }

    syncSettings = syncSettingsRepository.load()
    syncStatus = syncSettings.isConfigured ? .idle(lastSyncedAt: nil) : .notConfigured
  }
}

extension NornAppStore {
  static func preview(tasks: [Task] = NornPreviewFixtures.tasks) -> NornAppStore {
    let taskRepository = PreviewTaskRepository(tasks: tasks)
    let syncSettingsRepository = PreviewSyncSettingsRepository(settings: .empty)
    let store = NornAppStore(
      tasks: tasks,
      syncSettings: syncSettingsRepository.load(),
      syncStatus: .notConfigured,
      loadTasksUseCase: LoadTasksUseCase(repository: taskRepository),
      quickAddTaskUseCase: QuickAddTaskUseCase(repository: taskRepository),
      saveTaskDraftUseCase: SaveTaskDraftUseCase(repository: taskRepository),
      toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: taskRepository),
      archiveTaskUseCase: ArchiveTaskUseCase(repository: taskRepository),
      saveSyncSettingsUseCase: SaveSyncSettingsUseCase(repository: syncSettingsRepository),
      syncTasksUseCase: SyncTasksUseCase(repository: taskRepository, client: PreviewTaskSyncClient()),
      syncSettingsRepository: syncSettingsRepository
    )
    store.hasBootstrapped = true
    return store
  }
}

private final class PreviewTaskRepository: TaskRepositoryProtocol {
  private var storedTasks: [Task]

  init(tasks: [Task]) {
    self.storedTasks = tasks
  }

  func loadAll() throws -> [Task] {
    storedTasks
  }

  func save(_ tasks: [Task]) throws {
    storedTasks = tasks
  }

  func upsert(_ tasks: [Task]) throws {
    guard !tasks.isEmpty else { return }

    var byID = Dictionary(uniqueKeysWithValues: storedTasks.map { ($0.id, $0) })
    for task in tasks {
      byID[task.id] = task
    }
    storedTasks = Array(byID.values)
  }

  func archive(taskID: String) throws {
    guard let index = storedTasks.firstIndex(where: { $0.id == taskID }) else { return }
    storedTasks[index].status = .archived
    storedTasks[index].updatedAt = Date()
  }

  func toggleCompletion(taskID: String) throws {
    guard let index = storedTasks.firstIndex(where: { $0.id == taskID }) else { return }
    storedTasks[index].status = storedTasks[index].status == .done ? .todo : .done
    storedTasks[index].updatedAt = Date()
  }
}

private final class PreviewSyncSettingsRepository: SyncSettingsRepositoryProtocol {
  private var storedSettings: SyncSettings

  init(settings: SyncSettings) {
    self.storedSettings = settings
  }

  func load() -> SyncSettings {
    storedSettings
  }

  func save(_ settings: SyncSettings) {
    storedSettings = settings
  }
}

private struct PreviewTaskSyncClient: TaskSyncClientProtocol {
  func sync(tasks: [Task], settings: SyncSettings) async throws -> [Task] {
    tasks
  }
}
