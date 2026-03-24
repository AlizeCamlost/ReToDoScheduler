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
    guard let draft = QuickAddDraft.parse(rawInput: rawInput, dateProvider: dateProvider) else {
      return nil
    }

    let now = dateProvider()
    let task = Task(
      id: idGenerator(),
      title: draft.title,
      rawInput: draft.rawInput,
      estimatedMinutes: draft.estimatedMinutes,
      minChunkMinutes: draft.minChunkMinutes,
      dueAt: draft.dueAt,
      tags: draft.tags,
      createdAt: now,
      updatedAt: now
    )

    try repository.upsert([task])
    return task
  }
}
