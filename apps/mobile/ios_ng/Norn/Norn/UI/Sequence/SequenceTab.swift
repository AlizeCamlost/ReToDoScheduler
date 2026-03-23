import SwiftUI

struct SequenceTab: View {
  let tasks: [Task]
  let onTaskTap: (Task) -> Void
  let onPrimarySequenceReorder: ([String]) -> Void

  @State private var primarySequenceOrder: [String] = []

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
    let remainingIDs = canonicalPrimarySequenceTasks.map(\.id).filter { !orderedIDs.contains($0) }
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
    ZStack {
      NornScreenBackground()

      List {
        focusRow

        Section {
          if displayedPrimarySequenceTasks.isEmpty {
            EmptyPrimarySequenceCard()
              .listRowStyle(top: 4, bottom: 12)
          } else {
            ForEach(Array(displayedPrimarySequenceTasks.enumerated()), id: \.element.id) { index, task in
              SequenceTimelineRow(
                task: task,
                position: timelinePosition(for: index, count: displayedPrimarySequenceTasks.count),
                onTap: {
                  onTaskTap(task)
                }
              )
              .listRowStyle(top: index == 0 ? 4 : 8, bottom: index == displayedPrimarySequenceTasks.count - 1 ? 16 : 8)
            }
            .onMove(perform: movePrimarySequence)
          }
        }

        Section {
          NextTasksSummaryCard(tasks: nextTasks, onTaskTap: onTaskTap)
            .listRowStyle(top: 8, bottom: 24)
        } header: {
          Text("接下来")
            .textCase(nil)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .background(Color.clear)
      .environment(\.editMode, .constant(.active))
    }
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
    .listRowStyle(top: 12, bottom: 16)
  }

  private func syncPrimarySequenceOrder() {
    primarySequenceOrder = primarySequenceSignature
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

  private func movePrimarySequence(fromOffsets: IndexSet, toOffset: Int) {
    var reorderedIDs = displayedPrimarySequenceTasks.map(\.id)
    reorderedIDs.move(fromOffsets: fromOffsets, toOffset: toOffset)
    primarySequenceOrder = reorderedIDs
    onPrimarySequenceReorder(reorderedIDs)
  }
}

#Preview {
  SequenceTab(tasks: NornPreviewFixtures.tasks)
}

#Preview("Empty") {
  SequenceTab(tasks: [])
}

private enum TimelinePosition {
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
}

private struct SequenceTimelineRow: View {
  let task: Task
  let position: TimelinePosition
  let onTap: () -> Void

  private var statusColor: Color {
    TaskDisplayFormatter.statusColor(for: task.status)
  }

  private var metaItems: [String] {
    var items = [TaskDisplayFormatter.statusLabel(for: task.status), "估时 \(task.estimatedMinutes) 分钟"]
    if let dueLabel = RelativeDueDateFormatter.label(for: task.dueAt) {
      items.append(dueLabel)
    }
    if !task.tags.isEmpty {
      items.append(task.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
    }
    return items
  }

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      SequenceTimelineMarker(color: statusColor, position: position)

      Button(action: onTap) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 10) {
            Text(task.title)
              .font(.headline.weight(.semibold))
              .foregroundStyle(.primary)
              .lineLimit(2)

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
              .padding(.top, 2)

            Image(systemName: "chevron.right")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
              .padding(.top, 2)
          }

          if let description = task.description, !description.isEmpty {
            Text(description)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }

          FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(metaItems, id: \.self) { item in
              SequenceMetaPill(
                text: item,
                foreground: item == TaskDisplayFormatter.statusLabel(for: task.status) ? statusColor : .secondary,
                background: item == TaskDisplayFormatter.statusLabel(for: task.status)
                  ? statusColor.opacity(0.14)
                  : NornTheme.pillSurface
              )
            }
          }

          if !task.steps.isEmpty {
            Text("包含 \(task.steps.count) 个子步骤")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(NornTheme.cardSurface)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
        )
        .shadow(color: NornTheme.shadow, radius: 14, y: 6)
      }
      .buttonStyle(.plain)
    }
  }
}

private struct SequenceTimelineMarker: View {
  let color: Color
  let position: TimelinePosition

  private let railColor = Color.primary.opacity(0.16)

  var body: some View {
    VStack(spacing: 0) {
      lineSegment(visible: position.showsTopLine)
      Circle()
        .fill(color)
        .frame(width: 14, height: 14)
        .overlay(
          Circle()
            .strokeBorder(Color.white.opacity(0.78), lineWidth: 2)
        )
      lineSegment(visible: position.showsBottomLine)
    }
    .frame(width: 16)
    .frame(maxHeight: .infinity)
    .padding(.top, 10)
    .padding(.bottom, 10)
  }

  @ViewBuilder
  private func lineSegment(visible: Bool) -> some View {
    Rectangle()
      .fill(visible ? railColor : .clear)
      .frame(width: 2)
      .frame(maxHeight: .infinity)
  }
}

private struct SequenceMetaPill: View {
  let text: String
  let foreground: Color
  let background: Color

  var body: some View {
    Text(text)
      .font(.caption.weight(.medium))
      .foregroundStyle(foreground)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(background, in: Capsule())
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
    .shadow(color: NornTheme.shadow, radius: 16, y: 6)
  }
}

private struct EmptyPrimarySequenceCard: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("主序列暂时为空")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)

      Text("执行中的任务和近期待启动的任务会集中排列在这里，并支持拖拽重排。")
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

private extension View {
  func listRowStyle(top: CGFloat, bottom: CGFloat) -> some View {
    listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
  }
}

private struct FlowLayout: Layout {
  let spacing: CGFloat
  let lineSpacing: CGFloat

  init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
    self.spacing = spacing
    self.lineSpacing = lineSpacing
  }

  func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var currentLineWidth: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    var totalHeight: CGFloat = 0
    var maxLineWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      let nextWidth = currentLineWidth == 0 ? size.width : currentLineWidth + spacing + size.width

      if nextWidth > maxWidth, currentLineWidth > 0 {
        totalHeight += currentLineHeight + lineSpacing
        maxLineWidth = max(maxLineWidth, currentLineWidth)
        currentLineWidth = size.width
        currentLineHeight = size.height
      } else {
        currentLineWidth = nextWidth
        currentLineHeight = max(currentLineHeight, size.height)
      }
    }

    maxLineWidth = max(maxLineWidth, currentLineWidth)
    totalHeight += currentLineHeight
    return CGSize(width: maxLineWidth, height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    var currentOrigin = CGPoint(x: bounds.minX, y: bounds.minY)
    var currentLineHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      let nextX = currentOrigin.x == bounds.minX ? currentOrigin.x + size.width : currentOrigin.x + spacing + size.width

      if nextX > bounds.maxX, currentOrigin.x > bounds.minX {
        currentOrigin.x = bounds.minX
        currentOrigin.y += currentLineHeight + lineSpacing
        currentLineHeight = 0
      }

      subview.place(
        at: currentOrigin,
        proposal: ProposedViewSize(width: size.width, height: size.height)
      )

      currentOrigin.x += size.width + spacing
      currentLineHeight = max(currentLineHeight, size.height)
    }
  }
}
