import Foundation
@testable import Norn

final class InMemoryTaskRepository: TaskRepositoryProtocol {
  private(set) var tasks: [Task]

  init(tasks: [Task] = []) {
    self.tasks = tasks
  }

  func loadAll() throws -> [Task] {
    TaskOrdering.sorted(tasks)
  }

  func save(_ tasks: [Task]) throws {
    self.tasks = TaskOrdering.sorted(tasks)
  }

  func upsert(_ tasks: [Task]) throws {
    guard !tasks.isEmpty else { return }

    var byID = Dictionary(uniqueKeysWithValues: self.tasks.map { ($0.id, $0) })
    for task in tasks {
      let current = byID[task.id]
      if let current, current.updatedAt >= task.updatedAt {
        continue
      }
      byID[task.id] = task
    }
    self.tasks = TaskOrdering.sorted(Array(byID.values))
  }

  func archive(taskID: String) throws {
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    tasks[index].status = .archived
    tasks[index].updatedAt = Date()
  }

  func toggleCompletion(taskID: String) throws {
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    let nextStatus: TaskStatus = tasks[index].status == .done ? .todo : .done
    tasks[index] = tasks[index].settingStatus(nextStatus, updatedAt: Date())
  }

  func delete(taskID: String) throws {
    tasks.removeAll { $0.id == taskID }
  }
}

final class InMemoryTaskPoolOrganizationRepository: TaskPoolOrganizationRepositoryProtocol {
  private(set) var document: TaskPoolOrganizationDocument

  init(document: TaskPoolOrganizationDocument = .defaultValue()) {
    self.document = document.normalized()
  }

  func load() throws -> TaskPoolOrganizationDocument {
    document
  }

  func save(_ document: TaskPoolOrganizationDocument) throws {
    self.document = document.normalized()
  }
}

final class InMemorySyncSettingsRepository: SyncSettingsRepositoryProtocol {
  private var settings: SyncSettings

  init(settings: SyncSettings = .empty) {
    self.settings = settings
  }

  func load() -> SyncSettings {
    settings
  }

  func save(_ settings: SyncSettings) {
    self.settings = settings
  }
}

struct StubTaskSyncClient: TaskSyncClientProtocol {
  var handler: @Sendable ([Task], TaskPoolOrganizationDocument, SyncSettings) async throws -> TaskSyncSnapshot

  func sync(
    tasks: [Task],
    taskPoolOrganization: TaskPoolOrganizationDocument,
    settings: SyncSettings
  ) async throws -> TaskSyncSnapshot {
    try await handler(tasks, taskPoolOrganization, settings)
  }
}

func makeTask(
  id: String = UUID().uuidString,
  title: String = "Task",
  status: TaskStatus = .todo,
  estimatedMinutes: Int = 30,
  minChunkMinutes: Int = 25,
  dueAt: Date? = nil,
  tags: [String] = [],
  scheduleValue: TaskScheduleValue = .default,
  dependsOnTaskIDs: [String] = [],
  steps: [TaskStep] = [],
  createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
  updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
  extJSON: [String: JSONValue] = [:]
) -> Task {
  Task(
    id: id,
    title: title,
    rawInput: title,
    description: nil,
    status: status,
    estimatedMinutes: estimatedMinutes,
    minChunkMinutes: minChunkMinutes,
    dueAt: dueAt,
    tags: tags,
    scheduleValue: scheduleValue,
    dependsOnTaskIDs: dependsOnTaskIDs,
    steps: steps,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extJSON: extJSON
  )
}
