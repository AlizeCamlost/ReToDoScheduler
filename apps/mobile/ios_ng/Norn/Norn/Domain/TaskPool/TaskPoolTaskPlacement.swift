import Foundation

struct TaskPoolTaskPlacement: Hashable, Codable {
  var taskID: String
  var parentDirectoryID: String
  var sortOrder: Int

  init(
    taskID: String,
    parentDirectoryID: String,
    sortOrder: Int = 0
  ) {
    self.taskID = taskID
    self.parentDirectoryID = parentDirectoryID
    self.sortOrder = sortOrder
  }
}
