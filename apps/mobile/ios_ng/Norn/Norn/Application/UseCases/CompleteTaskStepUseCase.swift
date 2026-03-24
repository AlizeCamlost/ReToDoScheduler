import Foundation

struct CompleteTaskStepUseCase {
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
    stepID: String
  ) throws -> [Task] {
    let tasks = try repository.loadAll()
    guard let index = tasks.firstIndex(where: { $0.id == taskID }) else {
      return tasks
    }

    guard let updatedTask = tasks[index].completingStep(stepID: stepID, updatedAt: dateProvider()) else {
      return tasks
    }

    var updatedTasks = tasks
    updatedTasks[index] = updatedTask
    try repository.save(updatedTasks)
    return try repository.loadAll()
  }
}
