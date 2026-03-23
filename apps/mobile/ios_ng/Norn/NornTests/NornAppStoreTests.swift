import Foundation
import XCTest
@testable import Norn

@MainActor
final class NornAppStoreTests: XCTestCase {
  func testSubmitQuickAddCreatesTaskLocally() throws {
    let repository = InMemoryTaskRepository()
    let settingsRepository = InMemorySyncSettingsRepository()
    let store = makeStore(
      repository: repository,
      settingsRepository: settingsRepository
    )

    store.quickAddInput = "写周报 #work 45m 明天"
    store.submitQuickAdd()

    XCTAssertEqual(store.tasks.count, 1)
    XCTAssertEqual(store.tasks.first?.title, "写周报")
    XCTAssertEqual(store.tasks.first?.estimatedMinutes, 45)
    XCTAssertEqual(store.tasks.first?.tags, ["work"])
    XCTAssertTrue(store.quickAddInput.isEmpty)
  }

  func testSaveTaskDraftUpdatesExistingTask() throws {
    let existingTask = makeTask(id: "task-1", title: "Old", updatedAt: Date(timeIntervalSince1970: 100))
    let repository = InMemoryTaskRepository(tasks: [existingTask])
    let settingsRepository = InMemorySyncSettingsRepository()
    let store = makeStore(
      repository: repository,
      settingsRepository: settingsRepository,
      tasks: [existingTask]
    )

    var draft = TaskDraft(task: existingTask)
    draft.title = "Updated"
    draft.description = "More detail"
    draft.tags = ["ios", "sync"]
    draft.scheduleValue = TaskScheduleValue(rewardOnTime: 12, penaltyMissed: 40)

    store.saveTaskDraft(draft)

    XCTAssertEqual(store.tasks.first?.title, "Updated")
    XCTAssertEqual(store.tasks.first?.description, "More detail")
    XCTAssertEqual(store.tasks.first?.tags, ["ios", "sync"])
  }

  func testToggleCompletionAndArchiveUpdateStoreState() throws {
    let task = makeTask(id: "task-1", title: "Task", updatedAt: Date(timeIntervalSince1970: 100))
    let repository = InMemoryTaskRepository(tasks: [task])
    let settingsRepository = InMemorySyncSettingsRepository()
    let store = makeStore(
      repository: repository,
      settingsRepository: settingsRepository,
      tasks: [task]
    )

    store.toggleTaskCompletion(taskID: "task-1")
    XCTAssertEqual(store.tasks.first?.status, .done)

    store.openTaskDetail(taskID: "task-1")
    store.archiveTask(taskID: "task-1")
    XCTAssertEqual(store.tasks.first?.status, .archived)
    XCTAssertNil(store.selectedTask)
  }

  func testSaveSyncSettingsGeneratesDeviceID() {
    let repository = InMemoryTaskRepository()
    let settingsRepository = InMemorySyncSettingsRepository()
    let store = makeStore(
      repository: repository,
      settingsRepository: settingsRepository
    )

    store.saveSyncSettings(SyncSettings(baseURL: "https://sync.example.com", authToken: "token", deviceID: ""))

    XCTAssertTrue(store.syncSettings.isConfigured)
    XCTAssertFalse(store.syncSettings.deviceID.isEmpty)
  }

  func testReorderPrimarySequenceAssignsSyncedSequenceRanks() throws {
    let calendar = Calendar.current
    let nearDoing = makeTask(
      id: "task-1",
      title: "Doing",
      status: .doing,
      dueAt: calendar.date(byAdding: .day, value: 1, to: Date())
    )
    let nearTodo = makeTask(
      id: "task-2",
      title: "Near",
      dueAt: calendar.date(byAdding: .day, value: 2, to: Date())
    )
    let farTodo = makeTask(
      id: "task-3",
      title: "Far",
      dueAt: calendar.date(byAdding: .day, value: 14, to: Date())
    )

    let repository = InMemoryTaskRepository(tasks: [nearDoing, nearTodo, farTodo])
    let settingsRepository = InMemorySyncSettingsRepository()
    let store = makeStore(
      repository: repository,
      settingsRepository: settingsRepository,
      tasks: [nearDoing, nearTodo, farTodo]
    )

    store.reorderPrimarySequence(taskIDs: ["task-2", "task-1"])

    XCTAssertEqual(store.tasks.map(\.id), ["task-2", "task-1", "task-3"])
    XCTAssertEqual(TaskOrdering.sequenceRank(for: store.tasks[0]), 0)
    XCTAssertEqual(TaskOrdering.sequenceRank(for: store.tasks[1]), 1)
    XCTAssertEqual(TaskOrdering.sequenceRank(for: store.tasks[2]), 2)
  }

  private func makeStore(
    repository: InMemoryTaskRepository,
    settingsRepository: InMemorySyncSettingsRepository,
    tasks: [Task] = []
  ) -> NornAppStore {
    NornAppStore(
      tasks: tasks,
      syncSettings: settingsRepository.load(),
      syncStatus: .notConfigured,
      loadTasksUseCase: LoadTasksUseCase(repository: repository),
      quickAddTaskUseCase: QuickAddTaskUseCase(repository: repository),
      saveTaskDraftUseCase: SaveTaskDraftUseCase(repository: repository),
      reorderSequenceTasksUseCase: ReorderSequenceTasksUseCase(repository: repository),
      toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: repository),
      archiveTaskUseCase: ArchiveTaskUseCase(repository: repository),
      saveSyncSettingsUseCase: SaveSyncSettingsUseCase(repository: settingsRepository),
      syncTasksUseCase: SyncTasksUseCase(repository: repository, client: StubTaskSyncClient { tasks, _ in tasks }),
      syncSettingsRepository: settingsRepository
    )
  }
}
