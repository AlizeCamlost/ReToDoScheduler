import Foundation

struct TaskSyncRequest: Encodable {
  struct TaskPayload: Codable {
    struct StepPayload: Codable {
      var id: String
      var title: String
      var estimatedMinutes: Int
      var minChunkMinutes: Int
      var dependsOnStepIds: [String]

      init(step: TaskStep) {
        id = step.id
        title = step.title
        estimatedMinutes = step.estimatedMinutes
        minChunkMinutes = step.minChunkMinutes
        dependsOnStepIds = step.dependsOnStepIDs
      }

      func toDomain() -> TaskStep {
        TaskStep(
          id: id,
          title: title,
          estimatedMinutes: estimatedMinutes,
          minChunkMinutes: minChunkMinutes,
          dependsOnStepIDs: dependsOnStepIds
        )
      }
    }

    var id: String
    var title: String
    var rawInput: String
    var description: String?
    var status: TaskStatus
    var estimatedMinutes: Int
    var minChunkMinutes: Int
    var dueAt: String?
    var tags: [String]
    var scheduleValue: TaskScheduleValue
    var dependsOnTaskIds: [String]
    var steps: [StepPayload]
    var concurrencyMode: Task.ConcurrencyMode
    var createdAt: String
    var updatedAt: String
    var extJson: [String: JSONValue]

    init(task: Task) {
      id = task.id
      title = task.title
      rawInput = task.rawInput
      description = task.description
      status = task.status
      estimatedMinutes = task.estimatedMinutes
      minChunkMinutes = task.minChunkMinutes
      dueAt = ISO8601DateCodec.encode(task.dueAt)
      tags = task.tags
      scheduleValue = task.scheduleValue
      dependsOnTaskIds = task.dependsOnTaskIDs
      steps = task.steps.map(StepPayload.init(step:))
      concurrencyMode = task.concurrencyMode
      createdAt = ISO8601DateCodec.encode(task.createdAt) ?? ISO8601DateCodec.encode(Date()) ?? ""
      updatedAt = ISO8601DateCodec.encode(task.updatedAt) ?? ISO8601DateCodec.encode(Date()) ?? ""
      extJson = task.extJSON
    }

    func toDomain() -> Task {
      Task(
        id: id,
        title: title,
        rawInput: rawInput,
        description: description,
        status: status,
        estimatedMinutes: estimatedMinutes,
        minChunkMinutes: minChunkMinutes,
        dueAt: ISO8601DateCodec.decode(dueAt),
        tags: tags,
        scheduleValue: scheduleValue,
        dependsOnTaskIDs: dependsOnTaskIds,
        steps: steps.map { $0.toDomain() },
        concurrencyMode: concurrencyMode,
        createdAt: ISO8601DateCodec.decode(createdAt) ?? Date(),
        updatedAt: ISO8601DateCodec.decode(updatedAt) ?? Date(),
        extJSON: extJson
      )
    }
  }

  var deviceId: String
  var tasks: [TaskPayload]

  init(deviceID: String, tasks: [Task]) {
    deviceId = deviceID
    self.tasks = tasks.map(TaskPayload.init(task:))
  }
}
