import Foundation

protocol TaskRepositoryProtocol {
  func loadAll() throws -> [Task]
  func save(_ tasks: [Task]) throws
  func upsert(_ tasks: [Task]) throws
  func archive(taskID: String) throws
  func toggleCompletion(taskID: String) throws
}
