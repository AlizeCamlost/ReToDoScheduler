import Foundation

struct TaskFileRepository: TaskRepositoryProtocol {
  private let fileManager: FileManager
  private let baseDirectory: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(
    fileManager: FileManager = .default,
    baseDirectory: URL? = nil
  ) {
    self.fileManager = fileManager
    self.baseDirectory = baseDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder = encoder
    self.decoder = JSONDecoder()
  }

  func loadAll() throws -> [Task] {
    guard fileManager.fileExists(atPath: tasksFileURL.path) else {
      return []
    }

    let data = try Data(contentsOf: tasksFileURL)
    let records = try decoder.decode([TaskRecord].self, from: data)
    return TaskOrdering.sorted(records.map { $0.toDomain() })
  }

  func save(_ tasks: [Task]) throws {
    try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true, attributes: nil)
    let records = TaskOrdering.sorted(tasks).map(TaskRecord.init(task:))
    let data = try encoder.encode(records)
    try data.write(to: tasksFileURL, options: .atomic)
  }

  func upsert(_ tasks: [Task]) throws {
    guard !tasks.isEmpty else { return }

    var byID = Dictionary(uniqueKeysWithValues: try loadAll().map { ($0.id, $0) })
    for task in tasks {
      let current = byID[task.id]
      if let current, current.updatedAt >= task.updatedAt {
        continue
      }
      byID[task.id] = task
    }

    try save(Array(byID.values))
  }

  func archive(taskID: String) throws {
    var tasks = try loadAll()
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    tasks[index].status = .archived
    tasks[index].updatedAt = Date()
    try save(tasks)
  }

  func toggleCompletion(taskID: String) throws {
    var tasks = try loadAll()
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
    let nextStatus: TaskStatus = tasks[index].status == .done ? .todo : .done
    tasks[index] = tasks[index].settingStatus(nextStatus, updatedAt: Date())
    try save(tasks)
  }

  private var storageDirectory: URL {
    baseDirectory.appendingPathComponent("Norn", isDirectory: true)
  }

  private var tasksFileURL: URL {
    storageDirectory.appendingPathComponent("tasks.json")
  }
}
