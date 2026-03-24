import Foundation

struct Task: Identifiable, Hashable, Codable {
  enum ConcurrencyMode: String, Hashable, Codable {
    case serial
  }

  let id: String
  var title: String
  var rawInput: String
  var description: String?
  var status: TaskStatus
  var estimatedMinutes: Int
  var minChunkMinutes: Int
  var dueAt: Date?
  var tags: [String]
  var scheduleValue: TaskScheduleValue
  var dependsOnTaskIDs: [String]
  var steps: [TaskStep]
  var concurrencyMode: ConcurrencyMode
  var createdAt: Date
  var updatedAt: Date
  var extJSON: [String: JSONValue]

  init(
    id: String,
    title: String,
    rawInput: String? = nil,
    description: String? = nil,
    status: TaskStatus = .todo,
    estimatedMinutes: Int = 30,
    minChunkMinutes: Int = 25,
    dueAt: Date? = nil,
    tags: [String] = [],
    scheduleValue: TaskScheduleValue = .default,
    dependsOnTaskIDs: [String] = [],
    steps: [TaskStep] = [],
    concurrencyMode: ConcurrencyMode = .serial,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    extJSON: [String: JSONValue] = [:]
  ) {
    self.id = id
    self.title = title
    self.rawInput = rawInput ?? title
    self.description = description
    self.status = status
    self.estimatedMinutes = estimatedMinutes
    self.minChunkMinutes = minChunkMinutes
    self.dueAt = dueAt
    self.tags = tags
    self.scheduleValue = scheduleValue
    self.dependsOnTaskIDs = dependsOnTaskIDs
    self.steps = steps
    self.concurrencyMode = concurrencyMode
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.extJSON = extJSON
  }
}

extension Task {
  enum StepProgressState {
    case completed
    case current
    case upcoming
  }

  var completedStepCount: Int {
    steps.filter(\.isCompleted).count
  }

  var currentStepIndex: Int? {
    steps.firstIndex { !$0.isCompleted }
  }

  var currentStep: TaskStep? {
    guard let currentStepIndex else {
      return nil
    }
    return steps[currentStepIndex]
  }

  var allStepsCompleted: Bool {
    !steps.isEmpty && steps.allSatisfy(\.isCompleted)
  }

  var hasIncompleteSteps: Bool {
    steps.contains { !$0.isCompleted }
  }

  func stepProgressState(for stepID: String) -> StepProgressState? {
    guard let index = steps.firstIndex(where: { $0.id == stepID }) else {
      return nil
    }

    if steps[index].isCompleted {
      return .completed
    }

    if index == currentStepIndex {
      return .current
    }

    return .upcoming
  }

  func settingStatus(_ status: TaskStatus, updatedAt: Date) -> Task {
    var updatedTask = self
    updatedTask.status = status
    updatedTask.updatedAt = updatedAt

    switch status {
    case .todo:
      updatedTask.steps = updatedTask.steps.map { step in
        var updatedStep = step
        updatedStep.progress = nil
        return updatedStep
      }
    case .doing:
      if updatedTask.allStepsCompleted, !updatedTask.steps.isEmpty {
        updatedTask.steps = updatedTask.steps.map { step in
          var updatedStep = step
          updatedStep.progress = nil
          return updatedStep
        }
      }

      if let currentStepIndex = updatedTask.currentStepIndex {
        var currentStep = updatedTask.steps[currentStepIndex]
        currentStep.progress = TaskStepProgress(
          startedAt: currentStep.progress?.startedAt ?? updatedAt,
          completedAt: nil
        )
        updatedTask.steps[currentStepIndex] = currentStep
      }
    case .done:
      updatedTask.steps = updatedTask.steps.map { step in
        var updatedStep = step
        updatedStep.progress = TaskStepProgress(
          startedAt: step.progress?.startedAt ?? updatedAt,
          completedAt: updatedAt
        )
        return updatedStep
      }
    case .archived:
      break
    }

    return updatedTask
  }

  func appendingStep(
    _ step: TaskStep,
    updatedAt: Date
  ) -> Task {
    var updatedTask = self
    var nextStep = step
    if updatedTask.status == .doing && updatedTask.currentStep == nil {
      nextStep.progress = TaskStepProgress(startedAt: updatedAt)
    }
    if updatedTask.status == .done {
      nextStep.progress = TaskStepProgress(startedAt: updatedAt)
    }
    updatedTask.steps.append(nextStep)
    updatedTask.updatedAt = updatedAt

    if updatedTask.status == .done {
      updatedTask.status = .doing
    }

    return updatedTask
  }

  func completingStep(
    stepID: String,
    updatedAt: Date
  ) -> Task? {
    guard let currentStepIndex, steps[currentStepIndex].id == stepID else {
      return nil
    }

    var updatedTask = self
    updatedTask.steps[currentStepIndex].progress = TaskStepProgress(
      startedAt: updatedTask.steps[currentStepIndex].progress?.startedAt ?? updatedAt,
      completedAt: updatedAt
    )
    updatedTask.updatedAt = updatedAt
    if let nextStepIndex = updatedTask.steps.indices.dropFirst(currentStepIndex + 1).first(where: { !updatedTask.steps[$0].isCompleted }) {
      let nextStep = updatedTask.steps[nextStepIndex]
      updatedTask.steps[nextStepIndex].progress = TaskStepProgress(
        startedAt: nextStep.progress?.startedAt ?? updatedAt,
        completedAt: nextStep.progress?.completedAt
      )
    }
    updatedTask.status = updatedTask.steps.allSatisfy(\.isCompleted) ? .done : .doing
    return updatedTask
  }
}
