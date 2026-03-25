import Foundation

struct SaveTaskSequenceUseCase {
  private let repository: any TaskRepositoryProtocol
  private let dateProvider: () -> Date
  private let taskIDGenerator: () -> String
  private let bundleIDGenerator: () -> String

  init(
    repository: any TaskRepositoryProtocol,
    dateProvider: @escaping () -> Date = Date.init,
    taskIDGenerator: @escaping () -> String = { UUID().uuidString },
    bundleIDGenerator: @escaping () -> String = { UUID().uuidString }
  ) {
    self.repository = repository
    self.dateProvider = dateProvider
    self.taskIDGenerator = taskIDGenerator
    self.bundleIDGenerator = bundleIDGenerator
  }

  func execute(draft: TaskSequenceDraft) throws -> [Task] {
    let entries = draft.entries
      .map(\.rawInput)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    guard !entries.isEmpty else {
      return []
    }

    let bundleID = bundleIDGenerator()
    let bundleTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    let now = dateProvider()

    let tasks = entries.enumerated().map { index, rawInput in
      let quickAddDraft = QuickAddDraft.parse(rawInput: rawInput, dateProvider: dateProvider)
        ?? QuickAddDraft(rawInput: rawInput, title: rawInput)
      let bundleMetadata = TaskBundleMetadata(
        id: bundleID,
        title: bundleTitle,
        position: index,
        count: entries.count
      )

      return Task(
        id: taskIDGenerator(),
        title: quickAddDraft.title,
        rawInput: quickAddDraft.rawInput,
        estimatedMinutes: quickAddDraft.estimatedMinutes,
        minChunkMinutes: quickAddDraft.minChunkMinutes,
        dueAt: quickAddDraft.dueAt,
        tags: quickAddDraft.tags,
        createdAt: now,
        updatedAt: now,
        extJSON: bundleMetadata.applying(to: [:])
      )
    }

    try repository.upsert(tasks)
    return tasks
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
