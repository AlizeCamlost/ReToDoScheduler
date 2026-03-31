import Foundation

struct TaskPoolDirectory: Identifiable, Hashable, Codable {
  let id: String
  var name: String
  var parentDirectoryID: String?
  var sortOrder: Int

  init(
    id: String,
    name: String,
    parentDirectoryID: String? = nil,
    sortOrder: Int = 0
  ) {
    self.id = id
    self.name = name
    self.parentDirectoryID = parentDirectoryID
    self.sortOrder = sortOrder
  }
}
