import Foundation

struct DeleteTaskUseCase {
  private let repository: any TaskRepositoryProtocol

  init(repository: any TaskRepositoryProtocol) {
    self.repository = repository
  }

  func execute(taskID: String) throws -> [Task] {
    try repository.delete(taskID: taskID)
    return try repository.loadAll()
  }
}
