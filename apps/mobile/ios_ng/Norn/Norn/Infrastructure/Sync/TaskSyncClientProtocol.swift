import Foundation

protocol TaskSyncClientProtocol {
  func sync(
    tasks: [Task],
    taskPoolOrganization: TaskPoolOrganizationDocument,
    settings: SyncSettings
  ) async throws -> TaskSyncSnapshot
}
