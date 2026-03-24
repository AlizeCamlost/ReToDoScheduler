import SwiftUI

struct TaskDependencyPickerSheet: View {
  let currentTaskID: String?
  let allTasks: [Task]
  @Binding var selectedTaskIDs: [String]

  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""
  @State private var filter: TaskDependencyStatusFilter = .all

  private var selectableTasks: [Task] {
    allTasks.filter { task in
      task.id != currentTaskID
    }
  }

  private var selectedTaskIDSet: Set<String> {
    Set(selectedTaskIDs)
  }

  private var rankedTasks: [Task] {
    selectableTasks.sorted { lhs, rhs in
      compare(lhs, rhs)
    }
  }

  private var selectedTasks: [Task] {
    rankedTasks.filter { selectedTaskIDSet.contains($0.id) }
  }

  private var availableTasks: [Task] {
    rankedTasks.filter { !selectedTaskIDSet.contains($0.id) && matchesFilter($0) && matchesSearch($0) }
  }

  private var filteredCount: Int {
    rankedTasks.filter { !selectedTaskIDSet.contains($0.id) && matchesFilter($0) && matchesSearch($0) }.count
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 12) {
            Text("搜索并勾选前置依赖。已选任务会固定在顶部，方便随时回看。")
              .font(.footnote)
              .foregroundStyle(.secondary)

            Picker("筛选状态", selection: $filter) {
              ForEach(TaskDependencyStatusFilter.allCases) { item in
                Text(item.label).tag(item)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
          }
          .padding(.vertical, 4)
        }

        if !selectedTasks.isEmpty {
          Section {
            ForEach(selectedTasks) { task in
              TaskDependencyPickerRow(
                task: task,
                isSelected: true,
                onTap: {
                  toggleSelection(for: task.id)
                }
              )
            }
          } header: {
            Text("已选 \(selectedTasks.count) 项")
          }
        }

        Section {
          if availableTasks.isEmpty {
            EmptyDependencyState(
              title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "没有符合筛选条件的任务"
                : "没有匹配的任务",
              subtitle: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "可以切换状态筛选，或直接搜索标题、标签和描述。"
                : "试试换一个关键词，或者放宽状态筛选。"
            )
          } else {
            ForEach(availableTasks) { task in
              TaskDependencyPickerRow(
                task: task,
                isSelected: false,
                onTap: {
                  toggleSelection(for: task.id)
                }
              )
            }
          }
        } header: {
          Text(filteredCount > 0 ? "可选任务 · \(filteredCount)" : "可选任务")
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("前置依赖")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $searchText, prompt: "搜索标题、标签、描述")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") {
            dismiss()
          }
        }
      }
      .presentationDetents([.large])
    }
  }

  private func toggleSelection(for taskID: String) {
    if let index = selectedTaskIDs.firstIndex(of: taskID) {
      selectedTaskIDs.remove(at: index)
      return
    }

    selectedTaskIDs.append(taskID)
  }

  private func matchesFilter(_ task: Task) -> Bool {
    filter.status == nil || task.status == filter.status
  }

  private func matchesSearch(_ task: Task) -> Bool {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return true
    }

    let tokens = query
      .lowercased()
      .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
      .map(String.init)
      .filter { !$0.isEmpty }

    guard !tokens.isEmpty else {
      return true
    }

    return tokens.allSatisfy { token in
      fieldText(for: task).contains(token)
    }
  }

  private func compare(_ lhs: Task, _ rhs: Task) -> Bool {
    let lhsSelected = selectedTaskIDSet.contains(lhs.id)
    let rhsSelected = selectedTaskIDSet.contains(rhs.id)
    if lhsSelected != rhsSelected {
      return lhsSelected
    }

    let lhsScore = searchScore(for: lhs)
    let rhsScore = searchScore(for: rhs)
    if lhsScore != rhsScore {
      return lhsScore > rhsScore
    }

    let lhsPriority = statusPriority(for: lhs.status)
    let rhsPriority = statusPriority(for: rhs.status)
    if lhsPriority != rhsPriority {
      return lhsPriority < rhsPriority
    }

    switch (lhs.dueAt, rhs.dueAt) {
    case let (left?, right?):
      if left != right {
        return left < right
      }
    case (nil, _?):
      return false
    case (_?, nil):
      return true
    default:
      break
    }

    if lhs.updatedAt != rhs.updatedAt {
      return lhs.updatedAt > rhs.updatedAt
    }

    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
  }

  private func searchScore(for task: Task) -> Int {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else {
      return 0
    }

    let fields = SearchFields(
      title: task.title.lowercased(),
      description: task.description?.lowercased() ?? "",
      rawInput: task.rawInput.lowercased(),
      tags: task.tags.joined(separator: " ").lowercased(),
      id: task.id.lowercased()
    )

    return query
      .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
      .map(String.init)
      .filter { !$0.isEmpty }
      .reduce(0) { partialResult, token in
        partialResult + score(token: token, in: fields)
      }
  }

  private func score(token: String, in fields: SearchFields) -> Int {
    if fields.title == token {
      return 1000
    }
    if fields.title.hasPrefix(token) {
      return 900
    }
    if fields.title.contains(token) {
      return 800
    }
    if fields.tags.contains(token) {
      return 700
    }
    if fields.description.contains(token) {
      return 600
    }
    if fields.rawInput.contains(token) {
      return 500
    }
    if fields.id == token {
      return 400
    }
    if fields.id.contains(token) {
      return 300
    }
    return 0
  }

  private func statusPriority(for status: TaskStatus) -> Int {
    switch status {
    case .doing:
      return 0
    case .todo:
      return 1
    case .done:
      return 2
    case .archived:
      return 3
    }
  }

  private func fieldText(for task: Task) -> String {
    [
      task.title,
      task.description ?? "",
      task.rawInput,
      task.tags.joined(separator: " "),
      task.id
    ]
    .joined(separator: " ")
    .lowercased()
  }
}

private struct TaskDependencyPickerRow: View {
  let task: Task
  let isSelected: Bool
  let onTap: () -> Void

  private var statusLabel: String {
    TaskDisplayFormatter.statusLabel(for: task.status)
  }

  private var dueLabel: String? {
    RelativeDueDateFormatter.label(for: task.dueAt)
  }

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
          .padding(.top, 1)

        VStack(alignment: .leading, spacing: 6) {
          Text(task.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

          HStack(spacing: 6) {
            Text(statusLabel)
              .font(.caption.weight(.medium))
              .foregroundStyle(TaskDisplayFormatter.statusColor(for: task.status))

            if let dueLabel {
              Text(dueLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          if !task.tags.isEmpty {
            Text(task.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
              .font(.caption)
              .foregroundStyle(.tertiary)
              .lineLimit(1)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(.vertical, 6)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct EmptyDependencyState: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(subtitle)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 6)
  }
}

private struct SearchFields {
  let title: String
  let description: String
  let rawInput: String
  let tags: String
  let id: String
}

private enum TaskDependencyStatusFilter: String, CaseIterable, Identifiable {
  case all
  case todo
  case doing
  case done
  case archived

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:
      return "全部"
    case .todo:
      return "待开始"
    case .doing:
      return "进行中"
    case .done:
      return "已完成"
    case .archived:
      return "已归档"
    }
  }

  var status: TaskStatus? {
    switch self {
    case .all:
      return nil
    case .todo:
      return .todo
    case .doing:
      return .doing
    case .done:
      return .done
    case .archived:
      return .archived
    }
  }
}

#Preview {
  TaskDependencyPickerSheet(
    currentTaskID: "task-2",
    allTasks: NornPreviewFixtures.tasks,
    selectedTaskIDs: .constant(["task-1", "task-3"])
  )
}
