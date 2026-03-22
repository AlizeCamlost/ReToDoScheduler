import Foundation

struct SyncTasksUseCase {
  private let repository: any TaskRepositoryProtocol
  private let client: any TaskSyncClientProtocol

  init(
    repository: any TaskRepositoryProtocol,
    client: any TaskSyncClientProtocol
  ) {
    self.repository = repository
    self.client = client
  }

  func execute(settings: SyncSettings) async throws -> [Task] {
    let localTasks = try repository.loadAll()
    let syncedTasks = try await client.sync(tasks: localTasks, settings: settings)
    try repository.upsert(syncedTasks)
    return try repository.loadAll()
  }
}
