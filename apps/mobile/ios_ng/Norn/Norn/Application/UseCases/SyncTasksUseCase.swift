import Foundation

struct SyncTasksUseCase {
  private let taskRepository: any TaskRepositoryProtocol
  private let taskPoolOrganizationRepository: any TaskPoolOrganizationRepositoryProtocol
  private let client: any TaskSyncClientProtocol

  init(
    taskRepository: any TaskRepositoryProtocol,
    taskPoolOrganizationRepository: any TaskPoolOrganizationRepositoryProtocol,
    client: any TaskSyncClientProtocol
  ) {
    self.taskRepository = taskRepository
    self.taskPoolOrganizationRepository = taskPoolOrganizationRepository
    self.client = client
  }

  func execute(settings: SyncSettings) async throws -> TaskSyncSnapshot {
    let localTasks = try taskRepository.loadAll()
    let localTaskPoolOrganization = try taskPoolOrganizationRepository.load()
    let syncedSnapshot = try await client.sync(
      tasks: localTasks,
      taskPoolOrganization: localTaskPoolOrganization,
      settings: settings
    )
    try taskRepository.upsert(syncedSnapshot.tasks)
    try taskPoolOrganizationRepository.save(syncedSnapshot.taskPoolOrganization)
    return TaskSyncSnapshot(
      tasks: try taskRepository.loadAll(),
      taskPoolOrganization: try taskPoolOrganizationRepository.load()
    )
  }
}
