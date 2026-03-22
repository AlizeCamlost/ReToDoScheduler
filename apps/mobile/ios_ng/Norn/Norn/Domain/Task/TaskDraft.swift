import Foundation

struct TaskDraft: Hashable {
  var id: String?
  var title: String
  var rawInput: String
  var description: String
  var status: TaskStatus
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]
  var scheduleValue: TaskScheduleValue
  var dependsOnTaskIDs: [String]
  var steps: [TaskStep]
  var concurrencyMode: Task.ConcurrencyMode
  var extJSON: [String: String]

  init(
    id: String? = nil,
    title: String = "",
    rawInput: String = "",
    description: String = "",
    status: TaskStatus = .todo,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    tags: [String] = [],
    scheduleValue: TaskScheduleValue = .default,
    dependsOnTaskIDs: [String] = [],
    steps: [TaskStep] = [],
    concurrencyMode: Task.ConcurrencyMode = .serial,
    extJSON: [String: String] = [:]
  ) {
    self.id = id
    self.title = title
    self.rawInput = rawInput
    self.description = description
    self.status = status
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dueAt = dueAt
    self.tags = tags
    self.scheduleValue = scheduleValue
    self.dependsOnTaskIDs = dependsOnTaskIDs
    self.steps = steps
    self.concurrencyMode = concurrencyMode
    self.extJSON = extJSON
  }

  init(task: Task) {
    self.id = task.id
    self.title = task.title
    self.rawInput = task.rawInput
    self.description = task.description ?? ""
    self.status = task.status
    self.estimatedMinutes = task.estimatedMinutes
    self.minChunkMinutes = task.minChunkMinutes
    self.dueAt = task.dueAt
    self.tags = task.tags
    self.scheduleValue = task.scheduleValue
    self.dependsOnTaskIDs = task.dependsOnTaskIDs
    self.steps = task.steps
    self.concurrencyMode = task.concurrencyMode
    self.extJSON = task.extJSON
  }
}
