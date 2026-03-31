import Foundation

struct LoadTaskPoolOrganizationUseCase {
  private let repository: any TaskPoolOrganizationRepositoryProtocol

  init(repository: any TaskPoolOrganizationRepositoryProtocol) {
    self.repository = repository
  }

  func execute() throws -> TaskPoolOrganizationDocument {
    try repository.load()
  }
}
