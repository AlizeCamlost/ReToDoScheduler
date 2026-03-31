import Foundation

struct TaskSyncResponse: Decodable {
  var deviceId: String?
  var synced: Int?
  var items: [TaskSyncRequest.TaskPayload]
  var taskPoolOrganization: TaskPoolOrganizationRecord?

  func toTasks() -> [Task] {
    items.map { $0.toDomain() }
  }

  func toTaskPoolOrganization() -> TaskPoolOrganizationDocument? {
    taskPoolOrganization?.toDomain()
  }
}
