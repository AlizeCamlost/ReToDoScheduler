import Foundation

struct AppendTaskStepUseCase {
  private let repository: any TaskRepositoryProtocol
  private let dateProvider: () -> Date

  init(
    repository: any TaskRepositoryProtocol,
    dateProvider: @escaping () -> Date = Date.init
  ) {
    self.repository = repository
    self.dateProvider = dateProvider
  }

  func execute(
    taskID: String,
    title: String
  ) throws -> [Task] {
    let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let tasks = try repository.loadAll()

    guard
      !normalizedTitle.isEmpty,
      let index = tasks.firstIndex(where: { $0.id == taskID })
    else {
      return tasks
    }

    let task = tasks[index]
    let stepID = uniqueStepID(for: normalizedTitle, existingSteps: task.steps)
    let estimatedMinutes = max(task.minChunkMinutes, min(30, task.estimatedMinutes))
    let newStep = TaskStep(
      id: stepID,
      title: normalizedTitle,
      estimatedMinutes: estimatedMinutes,
      minChunkMinutes: min(task.minChunkMinutes, estimatedMinutes),
      dependsOnStepIDs: task.steps.last.map { [$0.id] } ?? []
    )

    var updatedTasks = tasks
    updatedTasks[index] = task.appendingStep(newStep, updatedAt: dateProvider())
    try repository.save(updatedTasks)
    return try repository.loadAll()
  }

  private func uniqueStepID(
    for title: String,
    existingSteps: [TaskStep]
  ) -> String {
    let existingIDs = Set(existingSteps.map(\.id))
    let baseID = slugify(title).nilIfEmpty ?? "step-\(existingSteps.count + 1)"

    guard !existingIDs.contains(baseID) else {
      for suffix in 2...(existingSteps.count + 20) {
        let candidate = "\(baseID)-\(suffix)"
        if !existingIDs.contains(candidate) {
          return candidate
        }
      }
      return "\(baseID)-\(UUID().uuidString.lowercased())"
    }

    return baseID
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
