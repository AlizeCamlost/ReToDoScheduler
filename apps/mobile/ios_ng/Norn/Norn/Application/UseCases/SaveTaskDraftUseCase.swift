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
    let resolvedTitle = normalizedTitle.isEmpty ? "未命名任务" : normalizedTitle
    let normalizedSteps = normalizeSteps(draft.steps)
    let validStepIDs = Set(normalizedSteps.map(\.id))

    let task = Task(
      id: taskID,
      title: resolvedTitle,
      rawInput: normalizedRawInput.isEmpty ? resolvedTitle : normalizedRawInput,
      description: draft.description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      status: draft.status,
      estimatedMinutes: max(1, draft.estimatedMinutes),
      minChunkMinutes: max(1, draft.minChunkMinutes),
      dueAt: draft.dueAt,
      tags: normalizeTags(draft.tags),
      scheduleValue: TaskScheduleValue(
        rewardOnTime: max(0, draft.scheduleValue.rewardOnTime),
        penaltyMissed: max(0, draft.scheduleValue.penaltyMissed)
      ),
      dependsOnTaskIDs: normalizeTaskDependencies(draft.dependsOnTaskIDs, taskID: taskID),
      steps: normalizedSteps.map { step in
        TaskStep(
          id: step.id,
          title: step.title,
          estimatedMinutes: step.estimatedMinutes,
          minChunkMinutes: step.minChunkMinutes,
          dependsOnStepIDs: step.dependsOnStepIDs.filter { validStepIDs.contains($0) && $0 != step.id }
        )
      },
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

    return steps.enumerated().compactMap { index, step in
      let normalizedTitle = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalizedTitle.isEmpty else {
        return nil
      }

      let fallbackID = slugify(normalizedTitle).nilIfEmpty ?? "step-\(index + 1)"
      let preferredID = step.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fallbackID
      let uniqueID = seenIDs.insert(preferredID).inserted ? preferredID : "\(preferredID)-\(index + 1)"
      seenIDs.insert(uniqueID)

      return TaskStep(
        id: uniqueID,
        title: normalizedTitle,
        estimatedMinutes: max(1, step.estimatedMinutes),
        minChunkMinutes: max(1, step.minChunkMinutes),
        dependsOnStepIDs: step.dependsOnStepIDs
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty && $0 != uniqueID }
      )
    }
  }

  private func normalizeTags(_ tags: [String]) -> [String] {
    var seen = Set<String>()

    return tags.compactMap { rawTag in
      let normalized = rawTag
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
        .lowercased()

      guard !normalized.isEmpty else {
        return nil
      }
      guard seen.insert(normalized).inserted else {
        return nil
      }
      return normalized
    }
  }

  private func normalizeTaskDependencies(_ taskIDs: [String], taskID: String) -> [String] {
    var seen = Set<String>()

    return taskIDs.compactMap { rawID in
      let normalized = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalized.isEmpty, normalized != taskID else {
        return nil
      }
      guard seen.insert(normalized).inserted else {
        return nil
      }
      return normalized
    }
  }

  private func slugify(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: #"[^\w\u4e00-\u9fa5-]+"#, with: "-", options: .regularExpression)
      .replacingOccurrences(of: #"^-+|-+$"#, with: "", options: .regularExpression)
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
