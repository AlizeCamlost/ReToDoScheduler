import Foundation

struct TaskRecord: Codable, Hashable {
  struct StepRecord: Codable, Hashable {
    struct ProgressRecord: Codable, Hashable {
      var startedAt: String?
      var completedAt: String?

      init(progress: TaskStepProgress) {
        startedAt = ISO8601DateCodec.encode(progress.startedAt)
        completedAt = ISO8601DateCodec.encode(progress.completedAt)
      }

      func toDomain() -> TaskStepProgress? {
        let progress = TaskStepProgress(
          startedAt: ISO8601DateCodec.decode(startedAt),
          completedAt: ISO8601DateCodec.decode(completedAt)
        )
        return progress.startedAt == nil && progress.completedAt == nil ? nil : progress
      }
    }

    var id: String
    var title: String
    var estimatedMinutes: Int
    var minChunkMinutes: Int
    var dependsOnStepIds: [String]
    var progress: ProgressRecord?

    init(step: TaskStep) {
      id = step.id
      title = step.title
      estimatedMinutes = step.estimatedMinutes
      minChunkMinutes = step.minChunkMinutes
      dependsOnStepIds = step.dependsOnStepIDs
      progress = step.progress.map(ProgressRecord.init(progress:))
    }

    func toDomain() -> TaskStep {
      TaskStep(
        id: id,
        title: title,
        estimatedMinutes: estimatedMinutes,
        minChunkMinutes: minChunkMinutes,
        dependsOnStepIDs: dependsOnStepIds,
        progress: progress?.toDomain()
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
  var steps: [StepRecord]
  var concurrencyMode: Task.ConcurrencyMode.RawValue
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
    steps = task.steps.map(StepRecord.init(step:))
    concurrencyMode = task.concurrencyMode.rawValue
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
      concurrencyMode: Task.ConcurrencyMode(rawValue: concurrencyMode) ?? .serial,
      createdAt: ISO8601DateCodec.decode(createdAt) ?? Date(),
      updatedAt: ISO8601DateCodec.decode(updatedAt) ?? Date(),
      extJSON: extJson
    )
  }
}
