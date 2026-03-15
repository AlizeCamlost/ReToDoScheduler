import Foundation

struct TaskEditorStepDraft: Identifiable, Equatable {
  let id: UUID
  var stepID: String
  var title: String
  var estimatedMinutes: String
  var minChunkMinutes: String
  var dependsOnStepIDsText: String

  init(
    id: UUID = UUID(),
    stepID: String = "",
    title: String = "",
    estimatedMinutes: String = "30",
    minChunkMinutes: String = "25",
    dependsOnStepIDsText: String = ""
  ) {
    self.id = id
    self.stepID = stepID
    self.title = title
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dependsOnStepIDsText = dependsOnStepIDsText
  }

  init(template: TaskStepTemplate) {
    self.init(
      stepID: template.id,
      title: template.title,
      estimatedMinutes: String(template.estimatedMinutes),
      minChunkMinutes: String(template.minChunkMinutes),
      dependsOnStepIDsText: template.dependsOnStepIds.joined(separator: ", ")
    )
  }
}

struct TaskEditorDraft: Equatable {
  var title: String
  var description: String
  var estimatedMinutes: String
  var minChunkMinutes: String
  var hasDueDate: Bool
  var dueDate: Date
  var tagsText: String
  var rewardOnTime: String
  var penaltyMissed: String
  var dependsOnTaskIds: [String]
  var steps: [TaskEditorStepDraft]
  var focus: FocusLevel
  var interruptibility: Interruptibility
  var location: LocationType
  var device: DeviceType

  init(task: Task? = nil) {
    title = task?.title ?? ""
    description = task?.description ?? ""
    estimatedMinutes = String(task?.estimatedMinutes ?? 30)
    minChunkMinutes = String(task?.minChunkMinutes ?? 25)
    hasDueDate = task?.dueAt != nil
    dueDate = task?.dueAt ?? Date()
    tagsText = task?.tags.joined(separator: ", ") ?? ""
    rewardOnTime = String(task?.scheduleValue.rewardOnTime ?? 10)
    penaltyMissed = String(task?.scheduleValue.penaltyMissed ?? 25)
    dependsOnTaskIds = task?.dependsOnTaskIds ?? []
    steps = (task?.steps ?? []).map(TaskEditorStepDraft.init(template:))
    focus = task?.taskTraits.focus ?? .medium
    interruptibility = task?.taskTraits.interruptibility ?? .medium
    location = task?.taskTraits.location ?? .any
    device = task?.taskTraits.device ?? .any
  }

  mutating func addStep() {
    let previousStepId = steps.last?.stepID.trimmingCharacters(in: .whitespacesAndNewlines)
    steps.append(
      TaskEditorStepDraft(
        stepID: "step-\(steps.count + 1)",
        dependsOnStepIDsText: previousStepId?.isEmpty == false ? previousStepId ?? "" : ""
      )
    )
  }

  mutating func removeStep(id: UUID) {
    steps.removeAll { $0.id == id }
  }

  func buildTask(existing: Task?) -> Task {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedTitle = cleanTitle.isEmpty ? (existing?.title ?? "Untitled Task") : cleanTitle
    let normalizedEstimated = max(1, Int(estimatedMinutes) ?? existing?.estimatedMinutes ?? 30)
    let normalizedChunk = max(1, Int(minChunkMinutes) ?? existing?.minChunkMinutes ?? 25)

    let normalizedSteps = normalizeSteps(fallbackEstimated: normalizedEstimated, fallbackChunk: normalizedChunk)
    let normalizedDueAt = hasDueDate
      ? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate)
      : nil

    return Task(
      id: existing?.id ?? UUID().uuidString,
      title: normalizedTitle,
      rawInput: existing?.rawInput ?? normalizedTitle,
      description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      status: existing?.status ?? .todo,
      estimatedMinutes: normalizedEstimated,
      minChunkMinutes: normalizedChunk,
      dueAt: normalizedDueAt,
      importance: existing?.importance ?? 3,
      value: existing?.value ?? 3,
      difficulty: existing?.difficulty ?? 3,
      postponability: existing?.postponability ?? 3,
      taskTraits: TaskTraits(
        focus: focus,
        interruptibility: interruptibility,
        location: location,
        device: device,
        parallelizable: false
      ),
      tags: tagsText
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") }
        .filter { !$0.isEmpty },
      scheduleValue: TaskValueSpec(
        rewardOnTime: max(0, Int(rewardOnTime) ?? existing?.scheduleValue.rewardOnTime ?? 10),
        penaltyMissed: max(0, Int(penaltyMissed) ?? existing?.scheduleValue.penaltyMissed ?? 25)
      ),
      dependsOnTaskIds: dependsOnTaskIds,
      steps: normalizedSteps,
      concurrencyMode: .serial,
      createdAt: existing?.createdAt ?? Date(),
      updatedAt: Date(),
      extJson: existing?.extJson ?? [:]
    )
  }

  private func normalizeSteps(fallbackEstimated: Int, fallbackChunk: Int) -> [TaskStepTemplate] {
    let mapped = steps.enumerated().map { index, step -> TaskStepTemplate in
      let stepID = step.stepID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "step-\(index + 1)"
      let title = step.title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "步骤 \(index + 1)"
      return TaskStepTemplate(
        id: stepID,
        title: title,
        estimatedMinutes: max(1, Int(step.estimatedMinutes) ?? fallbackEstimated),
        minChunkMinutes: max(1, Int(step.minChunkMinutes) ?? fallbackChunk),
        dependsOnStepIds: step.dependsOnStepIDsText
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      )
    }

    let validIDs = Set(mapped.map(\.id))
    return mapped.map { step in
      TaskStepTemplate(
        id: step.id,
        title: step.title,
        estimatedMinutes: step.estimatedMinutes,
        minChunkMinutes: step.minChunkMinutes,
        dependsOnStepIds: step.dependsOnStepIds.filter { validIDs.contains($0) && $0 != step.id }
      )
    }
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
