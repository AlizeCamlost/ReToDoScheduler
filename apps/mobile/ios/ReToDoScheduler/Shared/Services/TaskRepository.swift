import Foundation

enum AppSettingKey: String {
  case apiBaseURL = "api_base_url"
  case apiAuthToken = "api_auth_token"
  case deviceId = "device_id"
  case timeTemplate = "time_template"
}

struct QuickTaskDraft {
  var title: String
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]
  var taskTraits: TaskTraits
}

enum QuickInputParser {
  static func parse(_ input: String) -> QuickTaskDraft {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    return QuickTaskDraft(
      title: sanitizeTitle(trimmed).isEmpty ? "Untitled Task" : sanitizeTitle(trimmed),
      estimatedMinutes: parseDuration(trimmed),
      minChunkMinutes: parseMinChunk(trimmed),
      dueAt: parseDueDate(trimmed),
      tags: parseTags(trimmed),
      taskTraits: parseTraits(trimmed)
    )
  }

  private static func firstMatch(_ pattern: String, in source: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return nil
    }

    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = regex.firstMatch(in: source, options: [], range: range), match.numberOfRanges > 1,
          let captured = Range(match.range(at: 1), in: source) else {
      return nil
    }

    return String(source[captured])
  }

  private static func parseDuration(_ source: String) -> Int {
    let patterns = [
      "(\\d+)\\s*(?:分钟|mins?|minutes?)",
      "(\\d+)\\s*m\\b"
    ]

    for pattern in patterns {
      if let match = firstMatch(pattern, in: source), let value = Int(match) {
        return max(1, value)
      }
    }

    return 30
  }

  private static func parseMinChunk(_ source: String) -> Int {
    let patterns = [
      "至少\\s*(\\d+)\\s*分钟",
      "最少\\s*(\\d+)\\s*分钟",
      "min\\s*chunk\\s*(\\d+)"
    ]

    for pattern in patterns {
      if let match = firstMatch(pattern, in: source), let value = Int(match) {
        return max(1, value)
      }
    }

    return 25
  }

  private static func parseDueDate(_ source: String) -> Date? {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())

    if source.contains("今天") || source.range(of: "\\btoday\\b", options: [.regularExpression, .caseInsensitive]) != nil {
      return startOfToday
    }
    if source.contains("明天") || source.range(of: "\\btomorrow\\b", options: [.regularExpression, .caseInsensitive]) != nil {
      return calendar.date(byAdding: .day, value: 1, to: startOfToday)
    }
    if source.contains("后天") {
      return calendar.date(byAdding: .day, value: 2, to: startOfToday)
    }

    guard let regex = try? NSRegularExpression(pattern: "(\\d{4})-(\\d{1,2})-(\\d{1,2})") else {
      return nil
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    guard let match = regex.firstMatch(in: source, options: [], range: range),
          let yearRange = Range(match.range(at: 1), in: source),
          let monthRange = Range(match.range(at: 2), in: source),
          let dayRange = Range(match.range(at: 3), in: source),
          let year = Int(source[yearRange]),
          let month = Int(source[monthRange]),
          let day = Int(source[dayRange]) else {
      return nil
    }

    return calendar.date(from: DateComponents(year: year, month: month, day: day))
  }

  private static func parseTags(_ source: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: "#[\\w\\u4e00-\\u9fa5-]+") else {
      return []
    }

    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    let matches = regex.matches(in: source, options: [], range: range)
    return matches.compactMap { match in
      guard let range = Range(match.range, in: source) else { return nil }
      return String(source[range]).replacingOccurrences(of: "#", with: "").lowercased()
    }
  }

  private static func parseTraits(_ source: String) -> TaskTraits {
    var traits = TaskTraits.default

    if source.range(of: "专注|深度|focus", options: [.regularExpression, .caseInsensitive]) != nil {
      traits.focus = .high
      traits.interruptibility = .low
    }
    if source.range(of: "脑死亡|低认知|机械|挂机", options: .regularExpression) != nil {
      traits.focus = .low
      traits.interruptibility = .high
      traits.parallelizable = true
    }
    if source.range(of: "户外|outside|outdoor", options: [.regularExpression, .caseInsensitive]) != nil {
      traits.location = .outdoor
    }
    if source.range(of: "桌面|电脑|desktop", options: [.regularExpression, .caseInsensitive]) != nil {
      traits.device = .desktop
    }
    if source.range(of: "手机|mobile", options: [.regularExpression, .caseInsensitive]) != nil {
      traits.device = .mobile
    }
    if source.range(of: "可并行|并行|旁听", options: .regularExpression) != nil {
      traits.parallelizable = true
    }

    return traits
  }

  private static func sanitizeTitle(_ source: String) -> String {
    let noTags = source.replacingOccurrences(of: "#[\\w\\u4e00-\\u9fa5-]+", with: "", options: .regularExpression)
    return noTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

actor TaskRepository {
  static let shared = TaskRepository()

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let userDefaults = UserDefaults.standard

  private init() {
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  }

  func listTasks() async -> [Task] {
    let tasks = (try? loadTasks()) ?? []
    return tasks.sorted { left, right in
      if left.rank != right.rank {
        return left.rank < right.rank
      }
      return left.updatedAt > right.updatedAt
    }
  }

  func addTask(from rawInput: String) async throws {
    let draft = QuickInputParser.parse(rawInput)
    let task = Task(
      id: UUID().uuidString,
      title: draft.title,
      rawInput: rawInput,
      estimatedMinutes: draft.estimatedMinutes,
      minChunkMinutes: draft.minChunkMinutes,
      dueAt: draft.dueAt,
      taskTraits: draft.taskTraits,
      tags: draft.tags
    )
    try upsert([task])
  }

  func saveTask(_ task: Task) throws {
    try upsert([task])
  }

  func upsert(_ tasks: [Task]) throws {
    guard !tasks.isEmpty else { return }

    var existingById = Dictionary(uniqueKeysWithValues: ((try? loadTasks()) ?? []).map { ($0.id, $0) })
    for task in tasks {
      let normalized = task.withUpdatedTimestamp()
      if let previous = existingById[normalized.id], previous.updatedAt >= normalized.updatedAt {
        continue
      }
      existingById[normalized.id] = normalized
    }

    try save(Array(existingById.values))
  }

  func toggleDone(task: Task) throws {
    var tasks = (try? loadTasks()) ?? []
    guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
    tasks[index].status = tasks[index].status == .done ? .todo : .done
    tasks[index].updatedAt = Date()
    try save(tasks)
  }

  func archive(taskID: String) throws {
    var tasks = (try? loadTasks()) ?? []
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    tasks[index].status = .archived
    tasks[index].updatedAt = Date()
    try save(tasks)
  }

  func value(for setting: AppSettingKey) -> String {
    userDefaults.string(forKey: setting.rawValue) ?? ""
  }

  func setValue(_ value: String, for setting: AppSettingKey) {
    userDefaults.set(value, forKey: setting.rawValue)
  }

  func loadTimeTemplate() -> TimeTemplate {
    guard let data = userDefaults.data(forKey: AppSettingKey.timeTemplate.rawValue),
          let template = try? decoder.decode(TimeTemplate.self, from: data) else {
      return .default
    }

    return template
  }

  func saveTimeTemplate(_ template: TimeTemplate) {
    guard let data = try? encoder.encode(template) else { return }
    userDefaults.set(data, forKey: AppSettingKey.timeTemplate.rawValue)
  }

  func getOrCreateDeviceID() -> String {
    let existing = value(for: .deviceId)
    if !existing.isEmpty {
      return existing
    }

    let id = UUID().uuidString
    setValue(id, for: .deviceId)
    return id
  }

  private func save(_ tasks: [Task]) throws {
    let data = try encoder.encode(tasks)
    try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    try data.write(to: tasksFileURL, options: .atomic)
  }

  private func loadTasks() throws -> [Task] {
    guard FileManager.default.fileExists(atPath: tasksFileURL.path) else {
      return []
    }

    let data = try Data(contentsOf: tasksFileURL)
    return try decoder.decode([Task].self, from: data)
  }

  private var tasksFileURL: URL {
    storageDirectory.appendingPathComponent("tasks.json")
  }

  private var storageDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("ReToDoScheduler", isDirectory: true)
  }
}
