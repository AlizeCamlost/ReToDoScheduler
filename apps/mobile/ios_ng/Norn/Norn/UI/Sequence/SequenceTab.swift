import SwiftUI
import UniformTypeIdentifiers

struct SequenceTab: View {
  let tasks: [Task]
  let onTaskTap: (Task) -> Void
  let onPrimarySequenceReorder: ([String]) -> Void

  @State private var primarySequenceOrder: [String] = []
  @State private var draggedPrimaryTaskID: String?
  @State private var hasPendingPrimaryReorder = false

  init(
    tasks: [Task],
    onTaskTap: @escaping (Task) -> Void = { _ in },
    onPrimarySequenceReorder: @escaping ([String]) -> Void = { _ in }
  ) {
    self.tasks = tasks
    self.onTaskTap = onTaskTap
    self.onPrimarySequenceReorder = onPrimarySequenceReorder
  }

  private let nearHorizon = 7 // days

  private var focusedTask: Task? {
    tasks.first { $0.status == .doing }
  }

  private var canonicalPrimarySequenceTasks: [Task] {
    tasks.filter { task in
      task.status == .doing || (task.status == .todo && isWithinPrimaryHorizon(task))
    }
  }

  private var displayedPrimarySequenceTasks: [Task] {
    let byID = Dictionary(uniqueKeysWithValues: canonicalPrimarySequenceTasks.map { ($0.id, $0) })
    let orderedIDs = primarySequenceOrder.filter { byID[$0] != nil }
    let orderedIDSet = Set(orderedIDs)
    let remainingIDs = canonicalPrimarySequenceTasks.map(\.id).filter { !orderedIDSet.contains($0) }
    return (orderedIDs + remainingIDs).compactMap { byID[$0] }
  }

  private var nextTasks: [Task] {
    tasks.filter { task in
      task.status == .todo && !isWithinPrimaryHorizon(task)
    }
  }

  private var primarySequenceSignature: [String] {
    canonicalPrimarySequenceTasks.map(\.id)
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      LazyVStack(alignment: .leading, spacing: 0) {
        focusRow
          .padding(.top, 12)
          .padding(.bottom, 18)

        primarySequenceSection
          .padding(.bottom, 24)

        nextTasksSection
          .padding(.bottom, 24)
      }
      .padding(.horizontal, 20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color.clear)
    .onAppear(perform: syncPrimarySequenceOrder)
    .onChange(of: primarySequenceSignature) { _, _ in
      syncPrimarySequenceOrder()
    }
  }

  @ViewBuilder
  private var focusRow: some View {
    Group {
      if let task = focusedTask {
        FocusCard(task: task) {
          onTaskTap(task)
        }
      } else {
        EmptyFocusCard()
      }
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

  private var primarySequenceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SequenceSectionHeader(
        title: "主序列",
        detail: displayedPrimarySequenceTasks.count > 1 ? "长按右上角把手并拖动调整顺序" : nil
      )

      if displayedPrimarySequenceTasks.isEmpty {
        EmptyPrimarySequenceCard()
      } else {
        VStack(spacing: 0) {
          ForEach(Array(displayedPrimarySequenceTasks.enumerated()), id: \.element.id) { index, task in
            SequenceTimelineRow(
              task: task,
              position: timelinePosition(for: index, count: displayedPrimarySequenceTasks.count),
              dropEnabled: draggedPrimaryTaskID != nil,
              onDragStart: {
                draggedPrimaryTaskID = task.id
                hasPendingPrimaryReorder = false
                return NSItemProvider(object: task.id as NSString)
              },
              dropDelegate: PrimarySequenceDropDelegate(
                destinationTaskID: task.id,
                orderedTaskIDs: $primarySequenceOrder,
                draggedTaskID: $draggedPrimaryTaskID,
                hasPendingReorder: $hasPendingPrimaryReorder,
                onCommit: commitPrimarySequenceOrder
              ),
              onTap: {
                onTaskTap(task)
              }
            )
          }
        }
        .animation(.snappy(duration: 0.18, extraBounce: 0), value: primarySequenceOrder)
      }
    }
  }

  private var nextTasksSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SequenceSectionHeader(title: "接下来")
      NextTasksSummaryCard(tasks: nextTasks, onTaskTap: onTaskTap)
    }
  }

  private func commitPrimarySequenceOrder() {
    defer {
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

private struct SequenceTimelineRow: View {
  let task: Task
  let position: TimelinePosition
  let dropEnabled: Bool
  let onDragStart: () -> NSItemProvider
  let dropDelegate: PrimarySequenceDropDelegate
  let onTap: () -> Void

  private var statusColor: Color {
    TaskDisplayFormatter.statusColor(for: task.status)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      SequenceTimelineMarker(color: statusColor, position: position)

      ZStack(alignment: .topTrailing) {
        interactiveCard

        dragHandle
          .padding(.top, 20)
          .padding(.trailing, 16)
      }
    }
  }

  @ViewBuilder
  private var interactiveCard: some View {
    if dropEnabled {
      SequencePrimaryCard(task: task)
        .padding(.vertical, 8)
        .onTapGesture(perform: onTap)
        .onDrop(of: [UTType.plainText.identifier], delegate: dropDelegate)
    } else {
      SequencePrimaryCard(task: task)
        .padding(.vertical, 8)
        .onTapGesture(perform: onTap)
    }
  }

  private var dragHandle: some View {
    Image(systemName: "line.3.horizontal")
      .font(.caption.weight(.bold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(NornTheme.pillSurface, in: Capsule())
      .overlay(
        Capsule()
          .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
      )
      .contentShape(Capsule())
      .contentShape(.dragPreview, Capsule())
      .onDrag(onDragStart) {
        SequencePrimaryCard(task: task, isLifted: true)
      }
  }
}

private struct SequenceTimelineMarker: View {
  let color: Color
  let position: TimelinePosition

  private let railWidth: CGFloat = 2.5
  private let nodeDiameter: CGFloat = 14
  private let nodeCenterY: CGFloat = 24
  private let nodeLineGap: CGFloat = 5

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
          .fill(color.opacity(0.9))
          .frame(width: railWidth, height: max(0, nodeTopOffset - nodeLineGap))
      }

      if position.showsBottomLine {
        VStack(spacing: 0) {
          Color.clear
            .frame(height: nodeBottomOffset + nodeLineGap)

          Capsule(style: .continuous)
            .fill(color.opacity(0.78))
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
    .frame(width: 18)
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
        .init(color: color.opacity(0.95), location: 0),
        .init(color: color.opacity(0.38), location: 0.62),
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
  var isLifted: Bool = false

  private let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

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
    VStack(alignment: .leading, spacing: 8) {
      Text(task.title)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)
        .lineLimit(2)

      Text(metaSummary)
        .font(.caption.weight(.medium))
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
      .padding(.top, task.steps.isEmpty ? 0 : 2)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      cardShape
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      cardShape
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
    .shadow(
      color: NornTheme.shadow.opacity(isLifted ? 1 : 0.72),
      radius: isLifted ? 18 : 5,
      y: isLifted ? 8 : 2
    )
    .contentShape(cardShape)
    .contentShape(.dragPreview, cardShape)
  }
}

private struct SequenceSectionHeader: View {
  let title: String
  var detail: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)

      if let detail {
        Text(detail)
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.leading, 30)
  }
}

private struct NextTasksSummaryCard: View {
  let tasks: [Task]
  let onTaskTap: (Task) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if tasks.isEmpty {
        Text("暂无中远期任务")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)

        Text("更远的待办会在这里简略出现，不打断当前主序列。")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        ForEach(Array(tasks.prefix(4).enumerated()), id: \.element.id) { index, task in
          Button {
            onTaskTap(task)
          } label: {
            HStack(spacing: 10) {
              Circle()
                .fill(TaskDisplayFormatter.statusColor(for: task.status).opacity(0.8))
                .frame(width: 8, height: 8)

              Text(task.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

              Spacer(minLength: 8)

              if let dueLabel = RelativeDueDateFormatter.label(for: task.dueAt) {
                Text(dueLabel)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 2)
          }
          .buttonStyle(.plain)

          if index < min(tasks.count, 4) - 1 {
            Divider()
              .overlay(NornTheme.divider)
          }
        }

        if tasks.count > 4 {
          Text("还有 \(tasks.count - 4) 项等待进入主序列")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 4)
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 8]))
        .foregroundStyle(NornTheme.borderStrong)
    )
  }
}

private struct EmptyFocusCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("当前聚焦")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text("暂无正在进行的任务")
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
        }
        Spacer()
        Circle()
          .fill(NornTheme.borderStrong)
          .frame(width: 10, height: 10)
          .padding(.top, 4)
      }

      Text("开始一个任务后，这里会显示你当前最值得投入的事项。")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        EmptyFocusPill(text: "无进行中任务")
        EmptyFocusPill(text: "等待新建或开始")
      }

      VStack(alignment: .leading, spacing: 6) {
        EmptyFocusHint(text: "从底部输入框快速添加")
        EmptyFocusHint(text: "或从任务池挑一个开始")
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(NornTheme.cardSurface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
    .shadow(color: NornTheme.shadow.opacity(0.7), radius: 10, y: 4)
  }
}

private struct EmptyPrimarySequenceCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("主序列暂时为空")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)

      Text("执行中的任务和近期待启动的任务会集中排列在这里。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text("需要重排时，长按卡片右上角把手即可拖动。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(NornTheme.cardSurfaceMuted)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(NornTheme.border, lineWidth: 1)
    )
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
    HStack(spacing: 8) {
      Circle()
        .fill(NornTheme.borderStrong)
        .frame(width: 6, height: 6)
      Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PrimarySequenceDropDelegate: DropDelegate {
  let destinationTaskID: String
  @Binding var orderedTaskIDs: [String]
  @Binding var draggedTaskID: String?
  @Binding var hasPendingReorder: Bool
  let onCommit: () -> Void

  func dropEntered(info: DropInfo) {}

  private func reorderedTaskIDs() -> [String]? {
    guard
      let draggedTaskID,
      draggedTaskID != destinationTaskID,
      let fromIndex = orderedTaskIDs.firstIndex(of: draggedTaskID),
      let toIndex = orderedTaskIDs.firstIndex(of: destinationTaskID)
    else {
      return nil
    }

    var reorderedIDs = orderedTaskIDs
    reorderedIDs.move(
      fromOffsets: IndexSet(integer: fromIndex),
      toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
    )
    return reorderedIDs == orderedTaskIDs ? nil : reorderedIDs
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }

  func performDrop(info: DropInfo) -> Bool {
    if let reorderedTaskIDs = reorderedTaskIDs() {
      orderedTaskIDs = reorderedTaskIDs
      hasPendingReorder = true
    }
    onCommit()
    return true
  }
}
