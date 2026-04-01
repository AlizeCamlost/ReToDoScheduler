import SwiftUI
import UniformTypeIdentifiers

struct SequenceTab: View {
  let tasks: [Task]
  let isActive: Bool
  let onTaskTap: (Task) -> Void
  let onTaskComplete: (Task) -> Void
  let onTaskEdit: (Task) -> Void
  let onTaskArchive: (Task) -> Void
  let onTaskDelete: (Task) -> Void
  let onPrimarySequenceReorder: ([String]) -> Void

  @State private var primarySequenceOrder: [String] = []
  @State private var isPrimarySequenceEditing = false
  @State private var draggedPrimaryTaskID: String?
  @State private var hasPendingPrimaryReorder = false

  init(
    tasks: [Task],
    isActive: Bool = true,
    onTaskTap: @escaping (Task) -> Void = { _ in },
    onTaskComplete: @escaping (Task) -> Void = { _ in },
    onTaskEdit: @escaping (Task) -> Void = { _ in },
    onTaskArchive: @escaping (Task) -> Void = { _ in },
    onTaskDelete: @escaping (Task) -> Void = { _ in },
    onPrimarySequenceReorder: @escaping ([String]) -> Void = { _ in }
  ) {
    self.tasks = tasks
    self.isActive = isActive
    self.onTaskTap = onTaskTap
    self.onTaskComplete = onTaskComplete
    self.onTaskEdit = onTaskEdit
    self.onTaskArchive = onTaskArchive
    self.onTaskDelete = onTaskDelete
    self.onPrimarySequenceReorder = onPrimarySequenceReorder
  }

  private let nearHorizon = 7 // days
  private let primarySequenceLimit = 7

  private var focusedTask: Task? {
    tasks.first { $0.status == .doing }
  }

  private var canonicalPrimarySequenceTasks: [Task] {
    tasks.filter { task in
      task.status == .doing || (task.status == .todo && isWithinPrimaryHorizon(task))
    }
  }

  private var orderedPrimarySequenceTasks: [Task] {
    let byID = Dictionary(uniqueKeysWithValues: canonicalPrimarySequenceTasks.map { ($0.id, $0) })
    let orderedIDs = primarySequenceOrder.filter { byID[$0] != nil }
    let orderedIDSet = Set(orderedIDs)
    let remainingIDs = canonicalPrimarySequenceTasks.map(\.id).filter { !orderedIDSet.contains($0) }
    return (orderedIDs + remainingIDs).compactMap { byID[$0] }
  }

  private var displayedPrimarySequenceTasks: [Task] {
    Array(orderedPrimarySequenceTasks.prefix(primarySequenceLimit))
  }

  private var nextTasks: [Task] {
    let overflowTasks = Array(orderedPrimarySequenceTasks.dropFirst(primarySequenceLimit))
    let canonicalPrimaryTaskIDs = Set(canonicalPrimarySequenceTasks.map(\.id))
    let deferredTasks = tasks.filter { task in
      task.status == .todo && !canonicalPrimaryTaskIDs.contains(task.id)
    }
    return overflowTasks + deferredTasks
  }

  private var primarySequenceSignature: [String] {
    canonicalPrimarySequenceTasks.map(\.id)
  }

  var body: some View {
    List {
      focusSection
      currentSequenceSection
      nextTasksSection
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.clear)
    .onAppear(perform: syncPrimarySequenceOrder)
    .onChange(of: primarySequenceSignature) { _, _ in
      syncPrimarySequenceOrder()
    }
    .onChange(of: isActive) { _, nextValue in
      if !nextValue {
        completePrimarySequenceEditing()
      }
    }
    .onDisappear {
      completePrimarySequenceEditing()
    }
  }

  private var focusSection: some View {
    Section {
      Group {
        if let task = focusedTask {
          FocusCard(task: task) {
            if isPrimarySequenceEditing {
              completePrimarySequenceEditing()
            } else {
              onTaskTap(task)
            }
          }
        } else {
          EmptyFocusCard()
        }
      }
      .listRowInsets(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
    }
  }

  private var currentSequenceSection: some View {
    Section {
      if displayedPrimarySequenceTasks.isEmpty {
        EmptyPrimarySequenceCard()
          .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 10, trailing: 18))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      } else {
        ForEach(Array(displayedPrimarySequenceTasks.enumerated()), id: \.element.id) { index, task in
          SequenceTaskRow(
            task: task,
            position: timelinePosition(for: index, count: displayedPrimarySequenceTasks.count),
            isEditing: isPrimarySequenceEditing,
            isDragging: draggedPrimaryTaskID == task.id,
            onTap: {
              onTaskTap(task)
            },
            onLongPressToEdit: {
              beginPrimarySequenceEditing()
            },
            onDragStart: {
              draggedPrimaryTaskID = task.id
              hasPendingPrimaryReorder = false
              return NSItemProvider(object: task.id as NSString)
            },
            dropDelegate: SequenceReorderDropDelegate(
              destinationTaskID: task.id,
              orderedTaskIDs: $primarySequenceOrder,
              draggedTaskID: $draggedPrimaryTaskID,
              hasPendingReorder: $hasPendingPrimaryReorder,
              onCommit: commitPrimarySequenceOrder
            ),
            onComplete: {
              onTaskComplete(task)
              completePrimarySequenceEditing()
            },
            onEdit: {
              onTaskEdit(task)
              completePrimarySequenceEditing()
            },
            onArchive: {
              onTaskArchive(task)
              completePrimarySequenceEditing()
            },
            onDelete: {
              onTaskDelete(task)
              completePrimarySequenceEditing()
            }
          )
          .listRowInsets(EdgeInsets(top: index == 0 ? 2 : 0, leading: 18, bottom: 8, trailing: 18))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      }
    } header: {
      SequenceSectionHeader(
        title: "当前序列",
        detail: isPrimarySequenceEditing ? "上下拖拽排序，左滑可完成、编辑、归档或删除" : nil,
        actionTitle: isPrimarySequenceEditing ? "完成编辑" : nil,
        actionTint: TaskDisplayFormatter.statusColor(for: .doing),
        onAction: isPrimarySequenceEditing ? { completePrimarySequenceEditing() } : nil
      )
      .textCase(nil)
      .padding(.top, 4)
      .padding(.horizontal, 18)
    }
  }

  private var nextTasksSection: some View {
    Section {
      NextTasksSummaryCard(
        tasks: nextTasks,
        onTaskTap: { task in
          if isPrimarySequenceEditing {
            completePrimarySequenceEditing()
          } else {
            onTaskTap(task)
          }
        }
      )
        .listRowInsets(EdgeInsets(top: 4, leading: 18, bottom: 12, trailing: 18))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    } header: {
      SequenceSectionHeader(title: "接下来")
        .textCase(nil)
        .padding(.top, 6)
        .padding(.horizontal, 18)
    }
  }

  private func syncPrimarySequenceOrder() {
    guard
      primarySequenceOrder != primarySequenceSignature
        || draggedPrimaryTaskID != nil
        || hasPendingPrimaryReorder
    else {
      return
    }

    primarySequenceOrder = primarySequenceSignature
    isPrimarySequenceEditing = false
    draggedPrimaryTaskID = nil
    hasPendingPrimaryReorder = false
  }

  private func isWithinPrimaryHorizon(_ task: Task) -> Bool {
    guard let due = task.dueAt else { return true }
    let diff = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
    return diff <= nearHorizon
  }

  private func timelinePosition(for index: Int, count: Int) -> TimelinePosition {
    if count <= 1 {
      return .single
    }
    if index == 0 {
      return .first
    }
    if index == count - 1 {
      return .last
    }
    return .middle
  }

  private func beginPrimarySequenceEditing() {
    guard !displayedPrimarySequenceTasks.isEmpty else {
      return
    }
    isPrimarySequenceEditing = true
  }

  private func commitPrimarySequenceOrder() {
    guard hasPendingPrimaryReorder else {
      draggedPrimaryTaskID = nil
      return
    }
    onPrimarySequenceReorder(primarySequenceOrder)
    draggedPrimaryTaskID = nil
    hasPendingPrimaryReorder = false
  }

  private func completePrimarySequenceEditing() {
    defer {
      isPrimarySequenceEditing = false
      draggedPrimaryTaskID = nil
      hasPendingPrimaryReorder = false
    }

    guard hasPendingPrimaryReorder else { return }
    onPrimarySequenceReorder(primarySequenceOrder)
  }
}

#Preview {
  SequenceTab(tasks: NornPreviewFixtures.tasks)
}

#Preview("Empty") {
  SequenceTab(tasks: [])
}

private enum TimelinePosition: Equatable {
  case single
  case first
  case middle
  case last

  var showsTopLine: Bool {
    switch self {
    case .middle, .last:
      return true
    case .single, .first:
      return false
    }
  }

  var showsBottomLine: Bool {
    switch self {
    case .first, .middle:
      return true
    case .single, .last:
      return false
    }
  }

  var showsTrailingRay: Bool {
    switch self {
    case .single, .last:
      return true
    case .first, .middle:
      return false
    }
  }
}

private struct SequenceTaskRow: View {
  let task: Task
  let position: TimelinePosition
  let isEditing: Bool
  let isDragging: Bool
  let onTap: () -> Void
  let onLongPressToEdit: () -> Void
  let onDragStart: () -> NSItemProvider
  let dropDelegate: SequenceReorderDropDelegate
  let onComplete: () -> Void
  let onEdit: () -> Void
  let onArchive: () -> Void
  let onDelete: () -> Void

  private var statusColor: Color {
    TaskDisplayFormatter.statusColor(for: task.status)
  }

  var body: some View {
    let row = HStack(alignment: .top, spacing: 10) {
      SequenceTimelineMarker(color: statusColor, position: position)
      rowBody
    }
    .contentShape(Rectangle())

    if isEditing {
      row.swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button {
          onComplete()
        } label: {
          Label(task.status == .done ? "恢复" : "完成", systemImage: "checkmark.circle.fill")
        }
        .tint(.green)

        Button {
          onEdit()
        } label: {
          Label("编辑", systemImage: "pencil")
        }
        .tint(.blue)

        Button {
          onArchive()
        } label: {
          Label("归档", systemImage: "archivebox.fill")
        }
        .tint(.orange)

        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("删除", systemImage: "trash")
        }
      }
    } else {
      row
    }
  }

  @ViewBuilder
  private var rowBody: some View {
    let card = SequencePrimaryCard(task: task, isEditing: isEditing, isLifted: isDragging)

    if isEditing {
      card
        .onDrag(onDragStart) {
          SequencePrimaryCard(task: task, isEditing: true, isLifted: true)
        }
        .onDrop(of: [UTType.plainText.identifier], delegate: dropDelegate)
    } else {
      card
        .gesture(
          ExclusiveGesture(
            LongPressGesture(minimumDuration: 0.6),
            TapGesture()
          )
          .onEnded { value in
            switch value {
            case .first(true):
              onLongPressToEdit()
            case .first(false):
              break
            case .second(_):
              onTap()
            }
          }
        )
    }
  }
}

private struct SequenceTimelineMarker: View {
  let color: Color
  let position: TimelinePosition

  private let railWidth: CGFloat = 2
  private let nodeDiameter: CGFloat = 11
  private let nodeCenterY: CGFloat = 18
  private let nodeLineGap: CGFloat = 4

  private var nodeTopOffset: CGFloat {
    nodeCenterY - nodeDiameter / 2
  }

  private var nodeBottomOffset: CGFloat {
    nodeTopOffset + nodeDiameter
  }

  var body: some View {
    ZStack(alignment: .top) {
      if position.showsTopLine {
        Capsule(style: .continuous)
          .fill(color.opacity(0.88))
          .frame(width: railWidth, height: max(0, nodeTopOffset - nodeLineGap))
      }

      if position.showsBottomLine {
        VStack(spacing: 0) {
          Color.clear
            .frame(height: nodeBottomOffset + nodeLineGap)

          Capsule(style: .continuous)
            .fill(color.opacity(0.72))
            .frame(width: railWidth)
            .frame(maxHeight: .infinity)
        }
      }

      if position.showsTrailingRay {
        VStack(spacing: 0) {
          Color.clear
            .frame(height: nodeBottomOffset + nodeLineGap)

          SequenceTimelineTail(color: color, width: railWidth)
            .frame(maxHeight: .infinity)
        }
      }

      Circle()
        .fill(color)
        .frame(width: nodeDiameter, height: nodeDiameter)
        .overlay(
          Circle()
            .strokeBorder(color.opacity(0.16), lineWidth: 1)
        )
        .padding(.top, nodeCenterY - nodeDiameter / 2)
    }
    .frame(width: 12)
    .frame(maxHeight: .infinity)
    .allowsHitTesting(false)
  }
}

private struct SequenceTimelineTail: View {
  let color: Color
  let width: CGFloat

  var body: some View {
    LinearGradient(
      stops: [
        .init(color: color.opacity(0.94), location: 0),
        .init(color: color.opacity(0.32), location: 0.62),
        .init(color: color.opacity(0), location: 1)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(width: width)
  }
}

private struct SequencePrimaryCard: View {
  let task: Task
  var isEditing: Bool = false
  var isLifted: Bool = false

  private let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

  private var bundleMetadata: TaskBundleMetadata? {
    TaskBundleMetadata.metadata(for: task)
  }

  private var metaSummary: String {
    var items = [TaskDisplayFormatter.statusLabel(for: task.status), "估时 \(task.estimatedMinutes) 分钟"]
    if let dueLabel = RelativeDueDateFormatter.label(for: task.dueAt) {
      items.append(dueLabel)
    }
    return items.joined(separator: " · ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(task.title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      Text(metaSummary)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      if let bundleMetadata {
        TaskBundleBadge(metadata: bundleMetadata)
      }

      TaskStepPreviewView(
        task: task,
        style: .compact,
        accentColor: TaskDisplayFormatter.statusColor(for: task.status)
      )
      .padding(.top, task.steps.isEmpty ? 0 : 1)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      cardShape
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      cardShape
        .strokeBorder(isEditing ? NornTheme.borderStrong : NornTheme.border, lineWidth: 1)
    )
    .shadow(
      color: NornTheme.shadow.opacity(isLifted ? 1 : 0.72),
      radius: isLifted ? 18 : 5,
      y: isLifted ? 8 : 2
    )
    .contentShape(cardShape)
  }
}

private struct SequenceSectionHeader: View {
  let title: String
  var detail: String? = nil
  var actionTitle: String? = nil
  var actionTint: Color = .blue
  var onAction: (() -> Void)? = nil

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.secondary)

        if let detail {
          Text(detail)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }

      Spacer(minLength: 8)

      if let actionTitle, let onAction {
        Button(action: onAction) {
          Label(actionTitle, systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
              Capsule(style: .continuous)
                .fill(actionTint)
            )
        }
          .buttonStyle(.plain)
      }
    }
    .padding(.leading, 2)
    .padding(.trailing, 2)
  }
}

private struct NextTasksSummaryCard: View {
  let tasks: [Task]
  let onTaskTap: (Task) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if tasks.isEmpty {
        Text("暂无更多任务")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)

        Text("更后的待办会在这里简略出现，不打断当前序列。")
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ForEach(Array(tasks.prefix(5).enumerated()), id: \.element.id) { index, task in
          Button {
            onTaskTap(task)
          } label: {
            HStack(spacing: 8) {
              Circle()
                .fill(TaskDisplayFormatter.statusColor(for: task.status).opacity(0.8))
                .frame(width: 7, height: 7)

              Text(task.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

              Spacer(minLength: 8)

              if let dueLabel = RelativeDueDateFormatter.label(for: task.dueAt) {
                Text(dueLabel)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 1)
          }
          .buttonStyle(.plain)

          if index < min(tasks.count, 5) - 1 {
            Divider()
              .overlay(NornTheme.divider)
          }
        }

        if tasks.count > 5 {
          Text("还有 \(tasks.count - 5) 项等待进入当前序列")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 8]))
        .foregroundStyle(NornTheme.borderStrong)
    )
  }
}

private struct EmptyFocusCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("当前聚焦")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("暂无正在进行的任务")
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
        }
        Spacer()
        Circle()
          .fill(NornTheme.borderStrong)
          .frame(width: 8, height: 8)
          .padding(.top, 3)
      }

      Text("开始一个任务后，这里会显示你当前最值得投入的事项。")
        .font(.footnote)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        EmptyFocusPill(text: "无进行中任务")
        EmptyFocusPill(text: "等待新建或开始")
      }

      VStack(alignment: .leading, spacing: 5) {
        EmptyFocusHint(text: "从底部输入框快速添加")
        EmptyFocusHint(text: "或从任务池挑一个开始")
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
    .shadow(color: NornTheme.shadow.opacity(0.7), radius: 10, y: 4)
  }
}

private struct EmptyFocusPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(NornTheme.pillSurface, in: Capsule())
  }
}

private struct EmptyFocusHint: View {
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(NornTheme.borderStrong)
        .frame(width: 5, height: 5)
      Text(text)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

private struct EmptyPrimarySequenceCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("当前序列暂时为空")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      Text("执行中的任务和近期待启动的任务会集中排列在这里。")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(NornTheme.border, lineWidth: 1)
    )
  }
}

private struct SequenceReorderDropDelegate: DropDelegate {
  let destinationTaskID: String
  @Binding var orderedTaskIDs: [String]
  @Binding var draggedTaskID: String?
  @Binding var hasPendingReorder: Bool
  let onCommit: () -> Void

  func dropEntered(info: DropInfo) {
    updateOrder()
  }

  private func updateOrder() {
    guard
      let draggedTaskID,
      draggedTaskID != destinationTaskID,
      let fromIndex = orderedTaskIDs.firstIndex(of: draggedTaskID),
      let toIndex = orderedTaskIDs.firstIndex(of: destinationTaskID)
    else {
      return
    }

    var reorderedIDs = orderedTaskIDs
    reorderedIDs.move(
      fromOffsets: IndexSet(integer: fromIndex),
      toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
    )

    guard reorderedIDs != orderedTaskIDs else {
      return
    }

    orderedTaskIDs = reorderedIDs
    hasPendingReorder = true
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    updateOrder()
    onCommit()
    return true
  }
}
