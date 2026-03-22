import Foundation

struct QuickAddTaskUseCase {
  private let repository: any TaskRepositoryProtocol
  private let dateProvider: () -> Date
  private let idGenerator: () -> String

  init(
    repository: any TaskRepositoryProtocol,
    dateProvider: @escaping () -> Date = Date.init,
    idGenerator: @escaping () -> String = { UUID().uuidString }
  ) {
    self.repository = repository
    self.dateProvider = dateProvider
    self.idGenerator = idGenerator
  }

  func execute(rawInput: String) throws -> Task? {
    let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      return nil
    }

    let now = dateProvider()
    let task = Task(
      id: idGenerator(),
      title: trimmedInput,
      rawInput: trimmedInput,
      createdAt: now,
      updatedAt: now
    )

    try repository.upsert([task])
    return task
  }
}
