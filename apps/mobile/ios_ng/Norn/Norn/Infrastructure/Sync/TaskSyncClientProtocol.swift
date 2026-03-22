import Foundation

protocol TaskSyncClientProtocol {
  func sync(tasks: [Task], settings: SyncSettings) async throws -> [Task]
}
