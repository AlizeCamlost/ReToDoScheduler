import Foundation

struct SaveTaskPoolOrganizationUseCase {
  private let repository: any TaskPoolOrganizationRepositoryProtocol

  init(repository: any TaskPoolOrganizationRepositoryProtocol) {
    self.repository = repository
  }

  @discardableResult
  func execute(document: TaskPoolOrganizationDocument) throws -> TaskPoolOrganizationDocument {
    let normalizedDocument = document.normalized()
    try repository.save(normalizedDocument)
    return try repository.load()
  }
}
