import Foundation

enum DateCodec {
  private static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let plain: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  static func decode(_ value: String) throws -> Date {
    if let date = fractional.date(from: value) ?? plain.date(from: value) {
      return date
    }

    throw DecodingError.dataCorrupted(
      DecodingError.Context(codingPath: [], debugDescription: "Invalid ISO8601 date: \(value)")
    )
  }

  static func encode(_ value: Date) -> String {
    fractional.string(from: value)
  }
}

enum JSONValue: Codable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case object([String: JSONValue])
  case array([JSONValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }

  var objectValue: [String: JSONValue]? {
    if case .object(let value) = self {
      return value
    }
    return nil
  }

  var arrayValue: [JSONValue]? {
    if case .array(let value) = self {
      return value
    }
    return nil
  }

  var stringValue: String? {
    if case .string(let value) = self {
      return value
    }
    return nil
  }

  var doubleValue: Double? {
    if case .number(let value) = self {
      return value
    }
    return nil
  }

  var intValue: Int? {
    if case .number(let value) = self {
      return Int(value)
    }
    return nil
  }

  var boolValue: Bool? {
    if case .bool(let value) = self {
      return value
    }
    return nil
  }
}

enum TaskStatus: String, Codable, CaseIterable {
  case todo
  case doing
  case done
  case archived
}

enum FocusLevel: String, Codable {
  case high
  case medium
  case low
}

enum Interruptibility: String, Codable {
  case low
  case medium
  case high
}

enum LocationType: String, Codable {
  case indoor
  case outdoor
  case any
}

enum DeviceType: String, Codable {
  case desktop
  case mobile
  case any
}

enum ConcurrencyMode: String, Codable {
  case serial
}

struct TaskTraits: Codable, Equatable {
  var focus: FocusLevel
  var interruptibility: Interruptibility
  var location: LocationType
  var device: DeviceType
  var parallelizable: Bool

  static let `default` = TaskTraits(
    focus: .medium,
    interruptibility: .medium,
    location: .any,
    device: .any,
    parallelizable: false
  )
}

struct TaskValueSpec: Codable, Equatable {
  var rewardOnTime: Int
  var penaltyMissed: Int

  static let `default` = TaskValueSpec(rewardOnTime: 10, penaltyMissed: 25)
}

struct TaskStepTemplate: Codable, Equatable, Identifiable {
  var id: String
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dependsOnStepIds: [String]
}

struct TaskModelPayload: Equatable {
  var scheduleValue: TaskValueSpec
  var dependsOnTaskIds: [String]
  var steps: [TaskStepTemplate]
  var concurrencyMode: ConcurrencyMode
  var rank: Int?
}

struct Task: Codable, Equatable, Identifiable {
  var id: String
  var title: String
  var rawInput: String
  var description: String?
  var status: TaskStatus
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var importance: Int
  var value: Int
  var difficulty: Int
  var postponability: Int
  var taskTraits: TaskTraits
  var tags: [String]
  var scheduleValue: TaskValueSpec
  var dependsOnTaskIds: [String]
  var steps: [TaskStepTemplate]
  var concurrencyMode: ConcurrencyMode
  var createdAt: Date
  var updatedAt: Date
  var extJson: [String: JSONValue]

  enum CodingKeys: String, CodingKey {
    case id
    case title
    case rawInput
    case description
    case status
    case estimatedMinutes
    case minChunkMinutes
    case dueAt
    case importance
    case value
    case difficulty
    case postponability
    case taskTraits
    case tags
    case createdAt
    case updatedAt
    case extJson
  }

  init(
    id: String,
    title: String,
    rawInput: String,
    description: String? = nil,
    status: TaskStatus = .todo,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    importance: Int = 3,
    value: Int = 3,
    difficulty: Int = 3,
    postponability: Int = 3,
    taskTraits: TaskTraits = .default,
    tags: [String] = [],
    scheduleValue: TaskValueSpec = .default,
    dependsOnTaskIds: [String] = [],
    steps: [TaskStepTemplate] = [],
    concurrencyMode: ConcurrencyMode = .serial,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    extJson: [String: JSONValue] = [:]
  ) {
    self.id = id
    self.title = title
    self.rawInput = rawInput
    self.description = description
    self.status = status
    self.estimatedMinutes = max(1, estimatedMinutes)
    self.minChunkMinutes = max(1, minChunkMinutes)
    self.dueAt = dueAt
    self.importance = importance
    self.value = value
    self.difficulty = difficulty
    self.postponability = postponability
    self.taskTraits = taskTraits
    self.tags = tags
    self.scheduleValue = scheduleValue
    self.dependsOnTaskIds = dependsOnTaskIds
    self.steps = steps
    self.concurrencyMode = concurrencyMode
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.extJson = extJson
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    rawInput = try container.decode(String.self, forKey: .rawInput)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .todo
    estimatedMinutes = max(1, try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 30)
    minChunkMinutes = max(1, try container.decodeIfPresent(Int.self, forKey: .minChunkMinutes) ?? 25)
    if let due = try container.decodeIfPresent(String.self, forKey: .dueAt) {
      dueAt = try DateCodec.decode(due)
    } else {
      dueAt = nil
    }
    importance = try container.decodeIfPresent(Int.self, forKey: .importance) ?? 3
    value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 3
    difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 3
    postponability = try container.decodeIfPresent(Int.self, forKey: .postponability) ?? 3
    taskTraits = try container.decodeIfPresent(TaskTraits.self, forKey: .taskTraits) ?? .default
    tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    createdAt = try DateCodec.decode(try container.decode(String.self, forKey: .createdAt))
    updatedAt = try DateCodec.decode(try container.decode(String.self, forKey: .updatedAt))
    extJson = try container.decodeIfPresent([String: JSONValue].self, forKey: .extJson) ?? [:]

    let taskModel = Task.extractTaskModel(from: extJson)
    scheduleValue = taskModel?.scheduleValue ?? .default
    dependsOnTaskIds = taskModel?.dependsOnTaskIds ?? []
    steps = taskModel?.steps ?? []
    concurrencyMode = taskModel?.concurrencyMode ?? .serial
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(title, forKey: .title)
    try container.encode(rawInput, forKey: .rawInput)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encode(status, forKey: .status)
    try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
    try container.encode(minChunkMinutes, forKey: .minChunkMinutes)
    try container.encodeIfPresent(dueAt.map(DateCodec.encode), forKey: .dueAt)
    try container.encode(importance, forKey: .importance)
    try container.encode(value, forKey: .value)
    try container.encode(difficulty, forKey: .difficulty)
    try container.encode(postponability, forKey: .postponability)
    try container.encode(taskTraits, forKey: .taskTraits)
    try container.encode(tags, forKey: .tags)
    try container.encode(DateCodec.encode(createdAt), forKey: .createdAt)
    try container.encode(DateCodec.encode(updatedAt), forKey: .updatedAt)
    try container.encode(embeddingTaskModel(), forKey: .extJson)
  }

  var rank: Int {
    if let taskModel = extJson["taskModel"]?.objectValue {
      if let value = taskModel["rank"]?.intValue {
        return value
      }
    }
    return extJson["rank"]?.intValue ?? Int.max
  }

  func withUpdatedTimestamp() -> Task {
    var copy = self
    copy.updatedAt = Date()
    return copy
  }

  private static func extractTaskModel(from extJson: [String: JSONValue]) -> TaskModelPayload? {
    guard let taskModel = extJson["taskModel"]?.objectValue else {
      return nil
    }

    let scheduleRaw = taskModel["scheduleValue"]?.objectValue
    let scheduleValue = TaskValueSpec(
      rewardOnTime: scheduleRaw?["rewardOnTime"]?.intValue ?? 10,
      penaltyMissed: scheduleRaw?["penaltyMissed"]?.intValue ?? 25
    )

    let depends = taskModel["dependsOnTaskIds"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let steps = taskModel["steps"]?.arrayValue?.compactMap { value -> TaskStepTemplate? in
      guard let object = value.objectValue else { return nil }
      let id = object["id"]?.stringValue ?? UUID().uuidString
      let title = object["title"]?.stringValue ?? "步骤"
      let estimated = max(1, object["estimatedMinutes"]?.intValue ?? 30)
      let minChunk = max(1, object["minChunkMinutes"]?.intValue ?? 25)
      let dependsOn = object["dependsOnStepIds"]?.arrayValue?.compactMap { $0.stringValue } ?? []
      return TaskStepTemplate(
        id: id,
        title: title,
        estimatedMinutes: estimated,
        minChunkMinutes: minChunk,
        dependsOnStepIds: dependsOn
      )
    } ?? []

    let concurrencyMode = ConcurrencyMode(rawValue: taskModel["concurrencyMode"]?.stringValue ?? "") ?? .serial
    let rank = taskModel["rank"]?.intValue

    return TaskModelPayload(
      scheduleValue: scheduleValue,
      dependsOnTaskIds: depends,
      steps: steps,
      concurrencyMode: concurrencyMode,
      rank: rank
    )
  }

  private func embeddingTaskModel() -> [String: JSONValue] {
    var merged = extJson
    var taskModel = merged["taskModel"]?.objectValue ?? [:]

    taskModel["scheduleValue"] = .object([
      "rewardOnTime": .number(Double(scheduleValue.rewardOnTime)),
      "penaltyMissed": .number(Double(scheduleValue.penaltyMissed))
    ])
    taskModel["dependsOnTaskIds"] = .array(dependsOnTaskIds.map(JSONValue.string))
    taskModel["steps"] = .array(
      steps.map { step in
        .object([
          "id": .string(step.id),
          "title": .string(step.title),
          "estimatedMinutes": .number(Double(step.estimatedMinutes)),
          "minChunkMinutes": .number(Double(step.minChunkMinutes)),
          "dependsOnStepIds": .array(step.dependsOnStepIds.map(JSONValue.string))
        ])
      }
    )
    taskModel["concurrencyMode"] = .string(concurrencyMode.rawValue)

    merged["taskModel"] = .object(taskModel)
    return merged
  }
}

struct WeeklyTimeRange: Codable, Equatable, Identifiable {
  var id: String
  var weekday: Int
  var startTime: String
  var endTime: String
}

struct TimeTemplate: Codable, Equatable {
  var timezone: String
  var weeklyRanges: [WeeklyTimeRange]

  static let `default`: TimeTemplate = {
    let segments = [("09:00", "12:00"), ("14:00", "18:00"), ("19:00", "20:30")]
    var ranges: [WeeklyTimeRange] = []
    for weekday in 1...5 {
      for segment in segments {
        ranges.append(
          WeeklyTimeRange(
            id: "\(weekday)-\(segment.0)-\(segment.1)",
            weekday: weekday,
            startTime: segment.0,
            endTime: segment.1
          )
        )
      }
    }
    return TimeTemplate(timezone: TimeZone.current.identifier, weeklyRanges: ranges)
  }()
}

struct PlannedTimeSlot: Equatable, Identifiable {
  var id: String
  var startAt: Date
  var endAt: Date
  var durationMinutes: Int
}

struct ScheduleBlock: Equatable, Identifiable {
  var id: String
  var taskId: String
  var stepId: String?
  var slotId: String
  var startAt: Date
  var endAt: Date
  var isParallel: Bool
}

struct OrderedTaskStep: Equatable, Identifiable {
  var id: String { stepId }
  var stepId: String
  var taskId: String
  var taskTitle: String
  var title: String
  var dueAt: Date?
  var plannedMinutes: Int
  var remainingMinutes: Int
  var rewardOnTime: Int
  var penaltyMissed: Int
  var source: String
  var dependsOnStepIds: [String]
}

struct ScheduleWarning: Equatable, Identifiable {
  var id: String { "\(code)-\(taskId ?? "none")-\(stepId ?? "none")-\(message)" }
  var code: String
  var severity: String
  var message: String
  var taskId: String?
  var stepId: String?
}

struct ScheduleView: Equatable {
  var horizonStart: Date
  var horizonEnd: Date
  var slots: [PlannedTimeSlot]
  var blocks: [ScheduleBlock]
  var orderedSteps: [OrderedTaskStep]
  var unscheduledSteps: [OrderedTaskStep]
  var warnings: [ScheduleWarning]

  static let empty = ScheduleView(
    horizonStart: Date(),
    horizonEnd: Date(),
    slots: [],
    blocks: [],
    orderedSteps: [],
    unscheduledSteps: [],
    warnings: []
  )
}

struct ScheduleDayGroup: Identifiable {
  var id: String { dayKey }
  var dayKey: String
  var blocks: [ScheduleBlock]
}

enum HorizonOption: Int, CaseIterable, Identifiable {
  case day = 1
  case week = 7
  case short = 21
  case medium = 42

  var id: Int { rawValue }

  var label: String {
    switch self {
    case .day: return "1 天"
    case .week: return "7 天"
    case .short: return "21 天"
    case .medium: return "42 天"
    }
  }
}
