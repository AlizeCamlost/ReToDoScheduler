import Foundation

struct LoadTasksUseCase {
  private let repository: any TaskRepositoryProtocol

  init(repository: any TaskRepositoryProtocol) {
    self.repository = repository
  }

  func execute() throws -> [Task] {
    try repository.loadAll()
  }
}
