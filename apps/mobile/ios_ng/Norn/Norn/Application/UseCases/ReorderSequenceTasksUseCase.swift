import Foundation

struct ReorderSequenceTasksUseCase {
  private let repository: any TaskRepositoryProtocol
  private let dateProvider: () -> Date

  init(
    repository: any TaskRepositoryProtocol,
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.repository = repository
    self.dateProvider = dateProvider
  }

  func execute(primaryTaskIDs: [String]) throws -> [Task] {
    let allTasks = try repository.loadAll()
    let activeTasks = allTasks.filter { $0.status == .todo || $0.status == .doing }
    guard !activeTasks.isEmpty else {
      return allTasks
    }

    let activeTaskIDs = Set(activeTasks.map(\.id))
    var orderedTaskIDs: [String] = []
    var seen = Set<String>()

    for taskID in primaryTaskIDs where activeTaskIDs.contains(taskID) && seen.insert(taskID).inserted {
      orderedTaskIDs.append(taskID)
    }

    for task in activeTasks where seen.insert(task.id).inserted {
      orderedTaskIDs.append(task.id)
    }

    let rankByTaskID = Dictionary(uniqueKeysWithValues: orderedTaskIDs.enumerated().map { ($1, $0) })
    let now = dateProvider()
    var didChange = false

    let reorderedTasks = allTasks.map { task -> Task in
      guard let rank = rankByTaskID[task.id] else {
        return task
      }

      let currentRank = TaskOrdering.sequenceRank(for: task)
      guard currentRank != rank else {
        return task
      }

      didChange = true
      var updatedTask = TaskOrdering.applyingSequenceRank(rank, to: task)
      updatedTask.updatedAt = now
      return updatedTask
    }

    guard didChange else {
      return allTasks
    }

    try repository.save(reorderedTasks)
    return try repository.loadAll()
  }
}
