import Foundation

struct ArchiveTaskUseCase {
  private let repository: any TaskRepositoryProtocol

  init(repository: any TaskRepositoryProtocol) {
    self.repository = repository
  }

  func execute(taskID: String) throws -> [Task] {
    try repository.archive(taskID: taskID)
    return try repository.loadAll()
  }
}
