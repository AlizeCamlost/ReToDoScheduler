import Foundation

struct TaskSyncResponse: Decodable {
  var deviceId: String?
  var synced: Int?
  var items: [TaskSyncRequest.TaskPayload]

  func toTasks() -> [Task] {
    items.map { $0.toDomain() }
  }
}
