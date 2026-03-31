import Foundation

protocol TaskPoolOrganizationRepositoryProtocol {
  func load() throws -> TaskPoolOrganizationDocument
  func save(_ document: TaskPoolOrganizationDocument) throws
}
