import Foundation

struct TaskSyncSnapshot: Hashable {
  var tasks: [Task]
  var taskPoolOrganization: TaskPoolOrganizationDocument
}
