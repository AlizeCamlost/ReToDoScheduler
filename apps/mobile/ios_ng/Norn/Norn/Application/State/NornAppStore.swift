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
  @ObservationIgnored private let reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase
  @ObservationIgnored private let toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase
  @ObservationIgnored private let updateTaskStatusUseCase: UpdateTaskStatusUseCase
  @ObservationIgnored private let appendTaskStepUseCase: AppendTaskStepUseCase
  @ObservationIgnored private let completeTaskStepUseCase: CompleteTaskStepUseCase
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
    reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase,
    toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase,
    updateTaskStatusUseCase: UpdateTaskStatusUseCase,
    appendTaskStepUseCase: AppendTaskStepUseCase,
    completeTaskStepUseCase: CompleteTaskStepUseCase,
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
    self.reorderSequenceTasksUseCase = reorderSequenceTasksUseCase
    self.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
    self.updateTaskStatusUseCase = updateTaskStatusUseCase
    self.appendTaskStepUseCase = appendTaskStepUseCase
    self.completeTaskStepUseCase = completeTaskStepUseCase
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
    syncSettings = syncSettingsRepository.load()
    guard syncSettings.isConfigured else {
      syncStatus = .notConfigured
      tasks = (try? loadTasksUseCase.execute()) ?? tasks
      return
    }

    scheduleConservativeSyncIfNeeded()
  }

  func submitQuickAdd() {
    let rawInput = quickAddInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !rawInput.isEmpty else {
      quickAddInput = ""
      return
    }

    do {
      guard try quickAddTaskUseCase.execute(rawInput: rawInput) != nil else {
        return
      }

      tasks = try loadTasksUseCase.execute()
      quickAddInput = ""
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func openNewTaskDraftFromQuickAdd() {
    let seededDraft = QuickAddDraft.parse(rawInput: quickAddInput)?.taskDraft ?? TaskDraft()
    quickAddInput = ""
    closeTaskDetail()
    taskDraft = seededDraft
  }

  func openTaskDetail(taskID: String) {
    selectedTaskID = taskID
  }

  func closeTaskDetail() {
    selectedTaskID = nil
  }

  func openTaskEditor(taskID: String) {
    guard let task = tasks.first(where: { $0.id == taskID }) else { return }
    closeTaskDetail()
    taskDraft = TaskDraft(task: task)
  }

  func saveTaskDraft(_ draft: TaskDraft) {
    do {
      _ = try saveTaskDraftUseCase.execute(draft: draft)
      tasks = try loadTasksUseCase.execute()
      closeTaskEditor()
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func reorderPrimarySequence(taskIDs: [String]) {
    do {
      tasks = try reorderSequenceTasksUseCase.execute(primaryTaskIDs: taskIDs)
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func toggleTaskCompletion(taskID: String) {
    do {
      tasks = try toggleTaskCompletionUseCase.execute(taskID: taskID)
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func updateTaskStatus(
    taskID: String,
    status: TaskStatus
  ) {
    do {
      tasks = try updateTaskStatusUseCase.execute(taskID: taskID, status: status)
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func appendTaskStep(
    taskID: String,
    title: String
  ) {
    do {
      tasks = try appendTaskStepUseCase.execute(taskID: taskID, title: title)
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func completeTaskStep(
    taskID: String,
    stepID: String
  ) {
    do {
      tasks = try completeTaskStepUseCase.execute(taskID: taskID, stepID: stepID)
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func archiveTask(taskID: String) {
    do {
      tasks = try archiveTaskUseCase.execute(taskID: taskID)
      closeTaskDetail()
      scheduleConservativeSyncIfNeeded()
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  func closeTaskEditor() {
    taskDraft = nil
  }

  func saveSyncSettings(_ settings: SyncSettings) {
    let lastSyncedAt = currentLastSyncedAt
    syncSettings = saveSyncSettingsUseCase.execute(settings: settings)
    syncStatus = syncSettings.isConfigured ? .idle(lastSyncedAt: lastSyncedAt) : .notConfigured
    closeSyncSettings()
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
    syncStatus = syncSettings.isConfigured ? .idle(lastSyncedAt: currentLastSyncedAt) : .notConfigured
  }

  private func scheduleConservativeSyncIfNeeded() {
    guard syncSettings.isConfigured else {
      return
    }

    syncStatus = .syncing
    let settings = syncSettings
    _Concurrency.Task {
      await self.performConservativeSync(settings: settings)
    }
  }

  private func performConservativeSync(settings: SyncSettings) async {
    do {
      tasks = try await syncTasksUseCase.execute(settings: settings)
      syncStatus = .idle(lastSyncedAt: Date())
    } catch {
      syncStatus = .failed(message: error.localizedDescription)
    }
  }

  private var currentLastSyncedAt: Date? {
    if case let .idle(lastSyncedAt) = syncStatus {
      return lastSyncedAt
    }
    return nil
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
      reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase(repository: taskRepository),
      toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: taskRepository),
      updateTaskStatusUseCase: UpdateTaskStatusUseCase(repository: taskRepository),
      appendTaskStepUseCase: AppendTaskStepUseCase(repository: taskRepository),
      completeTaskStepUseCase: CompleteTaskStepUseCase(repository: taskRepository),
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
    TaskOrdering.sorted(storedTasks)
  }

  func save(_ tasks: [Task]) throws {
    storedTasks = TaskOrdering.sorted(tasks)
  }

  func upsert(_ tasks: [Task]) throws {
    guard !tasks.isEmpty else { return }

    var byID = Dictionary(uniqueKeysWithValues: storedTasks.map { ($0.id, $0) })
    for task in tasks {
      byID[task.id] = task
    }
    storedTasks = TaskOrdering.sorted(Array(byID.values))
  }

  func archive(taskID: String) throws {
    guard let index = storedTasks.firstIndex(where: { $0.id == taskID }) else { return }
    storedTasks[index].status = .archived
    storedTasks[index].updatedAt = Date()
  }

  func toggleCompletion(taskID: String) throws {
    guard let index = storedTasks.firstIndex(where: { $0.id == taskID }) else { return }
    let nextStatus: TaskStatus = storedTasks[index].status == .done ? .todo : .done
    storedTasks[index] = storedTasks[index].settingStatus(nextStatus, updatedAt: Date())
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
