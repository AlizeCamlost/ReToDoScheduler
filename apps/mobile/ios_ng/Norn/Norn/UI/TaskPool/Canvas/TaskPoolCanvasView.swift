import SwiftUI

struct TaskPoolCanvasView: View {
  let tasks: [Task]
  let organization: TaskPoolOrganizationDocument
  let onTaskTap: (Task) -> Void
  let onUpdateNode: (String, TaskPoolCanvasNodeLayout.NodeKind, Double, Double, Bool) -> Void

  @State private var dragTranslations: [String: CGSize] = [:]

  private let canvasSize = CGSize(width: 1_600, height: 1_200)

  private var normalizedOrganization: TaskPoolOrganizationDocument {
    organization.normalized()
  }

  private var visibleTasks: [Task] {
    tasks.filter { $0.status != .archived }
  }

  private var nodePresentations: [TaskPoolCanvasNodePresentation] {
    let normalized = normalizedOrganization
    let directories = normalized.directories
      .filter { $0.id != normalized.rootDirectoryID }
      .sorted(by: directorySortComparator)

    let directoryNodes = directories.enumerated().map { index, directory in
      let layout = layout(for: directory, index: index)
      return TaskPoolCanvasNodePresentation(
        nodeID: directory.id,
        nodeKind: .directory,
        title: displayName(for: directory),
        subtitle: directoryPathLabel(for: directory.id),
        detail: "\(childDirectories(of: directory.id).count) 个子目录 · \(tasks(in: directory.id).count) 个任务",
        position: layout.position,
        isCollapsed: layout.isCollapsed,
        accent: directory.id == normalized.inboxDirectoryID ? .inbox : .directory,
        task: nil
      )
    }

    let taskNodes = visibleTasks.enumerated().map { index, task in
      let layout = layout(for: task, index: index)
      return TaskPoolCanvasNodePresentation(
        nodeID: task.id,
        nodeKind: .task,
        title: task.title,
        subtitle: directoryPathLabel(for: directoryID(for: task.id)),
        detail: task.description,
        position: layout.position,
        isCollapsed: layout.isCollapsed,
        accent: .task(task.status),
        task: task
      )
    }

    return directoryNodes + taskNodes
  }

  var body: some View {
    ScrollView([.horizontal, .vertical], showsIndicators: false) {
      ZStack(alignment: .topLeading) {
        TaskPoolCanvasGridBackground()
          .frame(width: canvasSize.width, height: canvasSize.height)

        ForEach(nodePresentations) { node in
          TaskPoolCanvasNodeCard(
            node: node,
            onToggleCollapse: {
              let currentLayout = currentLayout(for: node)
              onUpdateNode(
                node.nodeID,
                node.nodeKind,
                currentLayout.position.x,
                currentLayout.position.y,
                !currentLayout.isCollapsed
              )
            },
            onTap: {
              if let task = node.task {
                onTaskTap(task)
              }
            }
          )
          .position(position(for: node))
          .gesture(dragGesture(for: node))
        }
      }
      .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
      .padding(28)
    }
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(NornTheme.cardSurface.opacity(0.32))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(NornTheme.borderStrong, lineWidth: 1)
    )
  }

  private func dragGesture(for node: TaskPoolCanvasNodePresentation) -> some Gesture {
    DragGesture()
      .onChanged { value in
        dragTranslations[node.id] = value.translation
      }
      .onEnded { value in
        dragTranslations[node.id] = nil
        let currentLayout = currentLayout(for: node)
        let nextPosition = clampedPosition(
          CGPoint(
            x: currentLayout.position.x + value.translation.width,
            y: currentLayout.position.y + value.translation.height
          )
        )
        onUpdateNode(
          node.nodeID,
          node.nodeKind,
          nextPosition.x,
          nextPosition.y,
          currentLayout.isCollapsed
        )
      }
  }

  private func position(for node: TaskPoolCanvasNodePresentation) -> CGPoint {
    let currentLayout = currentLayout(for: node)
    let translation = dragTranslations[node.id] ?? .zero
    return clampedPosition(
      CGPoint(
        x: currentLayout.position.x + translation.width,
        y: currentLayout.position.y + translation.height
      )
    )
  }

  private func currentLayout(for node: TaskPoolCanvasNodePresentation) -> (position: CGPoint, isCollapsed: Bool) {
    if let storedNode = normalizedOrganization.canvasNodes.first(where: { $0.nodeID == node.nodeID && $0.nodeKind == node.nodeKind }) {
      return (
        CGPoint(x: storedNode.x, y: storedNode.y),
        storedNode.isCollapsed
      )
    }

    return (node.position, node.isCollapsed)
  }

  private func layout(for directory: TaskPoolDirectory, index: Int) -> (position: CGPoint, isCollapsed: Bool) {
    if let storedNode = normalizedOrganization.canvasNodes.first(where: { $0.nodeID == directory.id && $0.nodeKind == .directory }) {
      return (CGPoint(x: storedNode.x, y: storedNode.y), storedNode.isCollapsed)
    }

    let depth = max(0, directoryDepth(for: directory.id) - 1)
    return (
      CGPoint(
        x: 220 + Double(depth) * 280,
        y: 170 + Double(index % 6) * 170 + Double(index / 6) * 24
      ),
      false
    )
  }

  private func layout(for task: Task, index: Int) -> (position: CGPoint, isCollapsed: Bool) {
    if let storedNode = normalizedOrganization.canvasNodes.first(where: { $0.nodeID == task.id && $0.nodeKind == .task }) {
      return (CGPoint(x: storedNode.x, y: storedNode.y), storedNode.isCollapsed)
    }

    let parentDirectoryID = directoryID(for: task.id)
    let siblingTasks = tasks(in: parentDirectoryID)
    let siblingIndex = siblingTasks.firstIndex(where: { $0.id == task.id }) ?? index
    let depth = directoryDepth(for: parentDirectoryID)
    return (
      CGPoint(
        x: 460 + Double(depth) * 280,
        y: 150 + Double(siblingIndex) * 156 + Double(max(0, index / 6)) * 18
      ),
      false
    )
  }

  private func clampedPosition(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, 120), canvasSize.width - 120),
      y: min(max(point.y, 90), canvasSize.height - 90)
    )
  }

  private func childDirectories(of directoryID: String) -> [TaskPoolDirectory] {
    normalizedOrganization.directories
      .filter { $0.parentDirectoryID == directoryID }
      .sorted(by: directorySortComparator)
  }

  private func tasks(in targetDirectoryID: String) -> [Task] {
    visibleTasks
      .filter { directoryID(for: $0.id) == targetDirectoryID }
      .sorted { lhs, rhs in
        switch (lhs.dueAt, rhs.dueAt) {
        case let (left?, right?) where left != right:
          return left < right
        case (.some, .none):
          return true
        case (.none, .some):
          return false
        default:
          return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
      }
  }

  private func directoryID(for taskID: String) -> String {
    normalizedOrganization.taskPlacement(for: taskID)?.parentDirectoryID ?? normalizedOrganization.inboxDirectoryID
  }

  private func directoryDepth(for directoryID: String) -> Int {
    var depth = 0
    var currentDirectoryID: String? = directoryID

    while let current = currentDirectoryID, let directory = normalizedOrganization.directory(for: current) {
      guard let parentDirectoryID = directory.parentDirectoryID else {
        return depth
      }
      depth += 1
      currentDirectoryID = parentDirectoryID
    }

    return depth
  }

  private func directoryPathLabel(for directoryID: String) -> String {
    var segments: [String] = []
    var currentDirectoryID: String? = directoryID

    while let current = currentDirectoryID, let directory = normalizedOrganization.directory(for: current) {
      segments.insert(displayName(for: directory), at: 0)
      currentDirectoryID = directory.parentDirectoryID
    }

    return segments.joined(separator: " / ")
  }

  private func displayName(for directory: TaskPoolDirectory) -> String {
    switch directory.id {
    case normalizedOrganization.rootDirectoryID:
      return "全部任务"
    case normalizedOrganization.inboxDirectoryID:
      return "待整理"
    default:
      return directory.name
    }
  }

  private var directorySortComparator: (TaskPoolDirectory, TaskPoolDirectory) -> Bool {
    { lhs, rhs in
      if lhs.sortOrder != rhs.sortOrder {
        return lhs.sortOrder < rhs.sortOrder
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }
}

private struct TaskPoolCanvasGridBackground: View {
  private let step: CGFloat = 88

  var body: some View {
    Canvas { context, size in
      var path = Path()

      stride(from: 0, through: size.width, by: step).forEach { x in
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
      }

      stride(from: 0, through: size.height, by: step).forEach { y in
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
      }

      context.stroke(
        path,
        with: .color(NornTheme.border.opacity(0.45)),
        lineWidth: 1
      )
    }
    .background(
      LinearGradient(
        colors: [
          NornTheme.cardSurface.opacity(0.88),
          NornTheme.cardSurfaceMuted.opacity(0.82)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 6) {
        Text("画布")
          .font(.headline.weight(.semibold))
        Text("拖拽节点调整布局，折叠状态和坐标都会写回同步文档。")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(22)
    }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }
}

#Preview {
  NornScreenBackground()
    .overlay {
      TaskPoolCanvasView(
        tasks: NornPreviewFixtures.tasks,
        organization: NornPreviewFixtures.taskPoolOrganization,
        onTaskTap: { _ in },
        onUpdateNode: { _, _, _, _, _ in }
      )
      .padding(20)
    }
}
