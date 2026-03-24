import Foundation

struct TaskStepProgress: Hashable, Codable {
  var startedAt: Date?
  var completedAt: Date?

  init(
    startedAt: Date? = nil,
    completedAt: Date? = nil
  ) {
    self.startedAt = startedAt
    self.completedAt = completedAt
  }
}
