import Foundation

struct SaveTaskDraftUseCase {
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

  func execute(draft: TaskDraft) throws -> Task {
    let existingTasks = try repository.loadAll()
    let taskID = draft.id ?? idGenerator()
    let existingTask = existingTasks.first { $0.id == taskID }
    let now = dateProvider()
    let normalizedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedRawInput = draft.rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

    let task = Task(
      id: taskID,
      title: normalizedTitle.isEmpty ? "未命名任务" : normalizedTitle,
      rawInput: normalizedRawInput.isEmpty ? normalizedTitle : normalizedRawInput,
      description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      status: draft.status,
      estimatedMinutes: draft.estimatedMinutes,
      minChunkMinutes: draft.minChunkMinutes,
      dueAt: draft.dueAt,
      tags: draft.tags,
      scheduleValue: draft.scheduleValue,
      dependsOnTaskIDs: draft.dependsOnTaskIDs.filter { $0 != taskID },
      steps: normalizeSteps(draft.steps),
      concurrencyMode: draft.concurrencyMode,
      createdAt: existingTask?.createdAt ?? now,
      updatedAt: now,
      extJSON: draft.extJSON
    )

    try repository.upsert([task])
    return task
  }

  private func normalizeSteps(_ steps: [TaskStep]) -> [TaskStep] {
    var seenIDs = Set<String>()

    return steps.enumerated().map { index, step in
      let fallbackID = "step-\(index + 1)"
      let normalizedID = step.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fallbackID
      let uniqueID = seenIDs.insert(normalizedID).inserted ? normalizedID : "\(normalizedID)-\(index + 1)"
      seenIDs.insert(uniqueID)

      return TaskStep(
        id: uniqueID,
        title: step.title.trimmingCharacters(in: .whitespacesAndNewlines),
        estimatedMinutes: step.estimatedMinutes,
        minChunkMinutes: step.minChunkMinutes,
        dependsOnStepIDs: step.dependsOnStepIDs.filter { $0 != uniqueID }
      )
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
