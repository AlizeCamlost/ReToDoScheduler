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
      toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase(repository: repository),
      archiveTaskUseCase: ArchiveTaskUseCase(repository: repository),
      saveSyncSettingsUseCase: SaveSyncSettingsUseCase(repository: settingsRepository),
      syncTasksUseCase: SyncTasksUseCase(repository: repository, client: StubTaskSyncClient { tasks, _ in tasks }),
      syncSettingsRepository: settingsRepository
    )
  }
}
