import Foundation
import SwiftUI

enum HomePerspective: Int, CaseIterable, Identifiable {
  case tasks
  case calendar

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .tasks: return "任务流"
    case .calendar: return "时间格"
    }
  }

  var subtitle: String {
    switch self {
    case .tasks: return "线性查看和收集任务"
    case .calendar: return "从时间维度查看排期"
    }
  }
}

enum CalendarDisplayMode: String, CaseIterable, Identifiable {
  case day
  case week
  case month

  var id: String { rawValue }

  var title: String {
    switch self {
    case .day: return "日"
    case .week: return "周"
    case .month: return "月"
    }
  }

  var horizon: HorizonOption {
    switch self {
    case .day: return .day
    case .week: return .week
    case .month: return .medium
    }
  }
}

@MainActor
final class AppViewModel: ObservableObject {
  @Published var input = ""
  @Published var searchQuery = ""
  @Published var tasks: [Task] = []
  @Published var timeTemplate = TimeTemplate.default
  @Published var syncMessage = "未同步"
  @Published var isSyncing = false
  @Published var horizon = HorizonOption.week
  @Published var apiBaseURL = ""
  @Published var apiAuthToken = ""
  @Published var showingSettings = false
  @Published var showingTaskEditor = false
  @Published var taskEditorDraft = TaskEditorDraft()
  @Published var currentPerspective: HomePerspective = .tasks
  @Published var calendarMode: CalendarDisplayMode = .week {
    didSet {
      horizon = calendarMode.horizon
    }
  }
  @Published var selectedTaskID: String?

  private(set) var editingTaskID: String?

  private let repository: TaskRepository
  private let syncService: SyncService
  private var autoSyncTask: _Concurrency.Task<Void, Never>?

  init(repository: TaskRepository = .shared, syncService: SyncService = SyncService()) {
    self.repository = repository
    self.syncService = syncService
  }

  deinit {
    autoSyncTask?.cancel()
  }

  var visibleTasks: [Task] {
    tasks.filter { $0.status != .archived }
  }

  var selectedTask: Task? {
    guard let selectedTaskID else { return nil }
    return tasks.first { $0.id == selectedTaskID }
  }

  var filteredTasks: [Task] {
    let byId = Dictionary(uniqueKeysWithValues: visibleTasks.map { ($0.id, $0) })
    let orderedIDs = Array(NSOrderedSet(array: scheduleView.orderedSteps.map(\.taskId))) as? [String] ?? []
    let ordered = orderedIDs.compactMap { byId[$0] }
    let missing = visibleTasks.filter { !orderedIDs.contains($0.id) }
    let merged = ordered + missing

    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return merged }

    return merged.filter {
      $0.title.lowercased().contains(query) ||
      ($0.description ?? "").lowercased().contains(query) ||
      $0.tags.contains { $0.lowercased().contains(query) }
    }
  }

  var scheduleView: ScheduleView {
    ScheduleEngine.refreshSchedule(tasks: visibleTasks, template: timeTemplate, now: Date(), horizonDays: horizon.rawValue)
  }

  var groupedBlocks: [ScheduleDayGroup] {
    ScheduleEngine.groupBlocksByDay(scheduleView.blocks)
  }

  func bootstrap() async {
    apiBaseURL = await repository.value(for: .apiBaseURL)
    apiAuthToken = await repository.value(for: .apiAuthToken)
    timeTemplate = await repository.loadTimeTemplate()
    await refresh()
    await syncNow(silentIfUnconfigured: true)
    startAutoSync()
  }

  func refresh() async {
    tasks = await repository.listTasks()
    if let selectedTaskID, !tasks.contains(where: { $0.id == selectedTaskID }) {
      self.selectedTaskID = nil
    }
  }

  func addTask() async {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }

    do {
      try await repository.addTask(from: value)
      input = ""
      await refresh()
      await syncNow(silentIfUnconfigured: true)
    } catch {
      syncMessage = "添加失败: \(error.localizedDescription)"
    }
  }

  func toggleDone(_ task: Task) async {
    do {
      try await repository.toggleDone(task: task)
      await refresh()
      await syncNow(silentIfUnconfigured: true)
    } catch {
      syncMessage = "更新失败: \(error.localizedDescription)"
    }
  }

  func archive(_ task: Task) async {
    do {
      try await repository.archive(taskID: task.id)
      if selectedTaskID == task.id {
        selectedTaskID = nil
      }
      await refresh()
      await syncNow(silentIfUnconfigured: true)
    } catch {
      syncMessage = "归档失败: \(error.localizedDescription)"
    }
  }

  func openCreateTaskEditor() {
    closeTaskDetail()
    editingTaskID = nil
    taskEditorDraft = TaskEditorDraft()
    showingTaskEditor = true
  }

  func openEditor(for task: Task) {
    closeTaskDetail()
    editingTaskID = task.id
    taskEditorDraft = TaskEditorDraft(task: task)
    showingTaskEditor = true
  }

  func closeTaskEditor() {
    showingTaskEditor = false
    editingTaskID = nil
  }

  func openTaskDetail(_ task: Task) {
    selectedTaskID = task.id
  }

  func closeTaskDetail() {
    selectedTaskID = nil
  }

  func saveTaskEditor(_ draft: TaskEditorDraft) async {
    let existing = tasks.first { $0.id == editingTaskID }

    do {
      try await repository.saveTask(draft.buildTask(existing: existing))
      closeTaskEditor()
      await refresh()
      await syncNow(silentIfUnconfigured: true)
    } catch {
      syncMessage = "保存失败: \(error.localizedDescription)"
    }
  }

  func saveSettings() {
    let trimmedBaseURL = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedToken = apiAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
    let template = timeTemplate

    _Concurrency.Task {
      await repository.setValue(trimmedBaseURL, for: .apiBaseURL)
      await repository.setValue(trimmedToken, for: .apiAuthToken)
      await repository.saveTimeTemplate(template)
    }
    showingSettings = false
  }

  func syncNow(silentIfUnconfigured: Bool = false) async {
    if isSyncing { return }

    let base = await repository.value(for: .apiBaseURL).trimmingCharacters(in: .whitespacesAndNewlines)
    let token = await repository.value(for: .apiAuthToken).trimmingCharacters(in: .whitespacesAndNewlines)
    if silentIfUnconfigured && (base.isEmpty || token.isEmpty) {
      syncMessage = "未配置同步"
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    do {
      let count = try await syncService.syncTasks()
      await refresh()
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      syncMessage = "已同步 \(count) 项，\(formatter.string(from: Date()))"
    } catch {
      syncMessage = "同步失败: \(error.localizedDescription)"
    }
  }

  private func startAutoSync() {
    guard autoSyncTask == nil else { return }

    autoSyncTask = _Concurrency.Task {
      while !_Concurrency.Task.isCancelled {
        try? await _Concurrency.Task.sleep(nanoseconds: 30 * 1_000_000_000)
        await syncNow(silentIfUnconfigured: true)
      }
    }
  }

  func taskTitle(for block: ScheduleBlock) -> String {
    if let stepID = block.stepId,
       let step = scheduleView.orderedSteps.first(where: { $0.stepId == stepID }) {
      return "\(step.taskTitle) / \(step.title)"
    }

    return visibleTasks.first(where: { $0.id == block.taskId })?.title ?? "任务"
  }

  func task(for block: ScheduleBlock) -> Task? {
    visibleTasks.first(where: { $0.id == block.taskId })
  }

  func task(for taskID: String) -> Task? {
    visibleTasks.first(where: { $0.id == taskID })
  }
}
