import Foundation

struct Task: Identifiable, Hashable, Codable {
  enum ConcurrencyMode: String, Hashable, Codable {
    case serial
  }

  let id: String
  var title: String
  var rawInput: String
  var description: String?
  var status: TaskStatus
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]
  var scheduleValue: TaskScheduleValue
  var dependsOnTaskIDs: [String]
  var steps: [TaskStep]
  var concurrencyMode: ConcurrencyMode
  var createdAt: Date
  var updatedAt: Date
  var extJSON: [String: String]

  init(
    id: String,
    title: String,
    rawInput: String? = nil,
    description: String? = nil,
    status: TaskStatus = .todo,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    tags: [String] = [],
    scheduleValue: TaskScheduleValue = .default,
    dependsOnTaskIDs: [String] = [],
    steps: [TaskStep] = [],
    concurrencyMode: ConcurrencyMode = .serial,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    extJSON: [String: String] = [:]
  ) {
    self.id = id
    self.title = title
    self.rawInput = rawInput ?? title
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
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.extJSON = extJSON
  }
}
