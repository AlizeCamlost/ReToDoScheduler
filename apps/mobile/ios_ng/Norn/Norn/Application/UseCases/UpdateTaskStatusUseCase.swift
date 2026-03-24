import Foundation

struct UpdateTaskStatusUseCase {
  private let repository: any TaskRepositoryProtocol
  private let dateProvider: () -> Date

  init(
    repository: any TaskRepositoryProtocol,
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.repository = repository
    self.dateProvider = dateProvider
  }

  func execute(
    taskID: String,
    status: TaskStatus
  ) throws -> [Task] {
    let tasks = try repository.loadAll()
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
      return tasks
    }

    var updatedTasks = tasks
    updatedTasks[index] = updatedTasks[index].settingStatus(status, updatedAt: dateProvider())
    try repository.save(updatedTasks)
    return try repository.loadAll()
  }
}
