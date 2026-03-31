import CoreGraphics
import Foundation

struct TaskPoolCanvasMindMap {
  struct NodeKey: Hashable {
    let nodeID: String
    let nodeKind: TaskPoolCanvasNodeLayout.NodeKind

    var stableID: String {
      "\(nodeKind.rawValue):\(nodeID)"
    }
  }

  enum AccentKind: Hashable {
    case directory
    case inbox
    case task(TaskStatus)
  }

  struct Node: Identifiable, Hashable {
    var id: String {
      key.stableID
    }

    let key: NodeKey
    let title: String
    let subtitle: String
    let detail: String?
    let position: CGPoint
    let isCollapsed: Bool
    let hasChildren: Bool
    let accent: AccentKind
    let task: Task?
  }

  struct Edge: Identifiable, Hashable {
    var id: String {
      "\(parent.stableID)->\(child.stableID)"
    }

    let parent: NodeKey
    let child: NodeKey
  }

  let nodes: [Node]
  let edges: [Edge]

  init(tasks: [Task], organization: TaskPoolOrganizationDocument) {
    let builder = Builder(tasks: tasks, organization: organization)
    let result = builder.build()
    nodes = result.nodes
    edges = result.edges
  }
}

private extension TaskPoolCanvasMindMap {
  enum TreeElement {
    case directory(TaskPoolDirectory)
    case task(Task)
  }

  struct BuildResult {
    let nodes: [Node]
    let edges: [Edge]
  }

  struct VisibleNode {
    let key: NodeKey
    let title: String
    let subtitle: String
    let detail: String?
    let isCollapsed: Bool
    let hasChildren: Bool
    let accent: AccentKind
    let task: Task?
    let children: [VisibleNode]
  }

  struct Builder {
    private static let leadingInset: CGFloat = 240
    private static let topInset: CGFloat = 150
    private static let horizontalSpacing: CGFloat = 300
    private static let siblingSpacing: CGFloat = 28
    private static let rootSubtreeSpacing: CGFloat = 64
    private static let expandedDirectoryHeight: CGFloat = 124
    private static let collapsedDirectoryHeight: CGFloat = 92
    private static let taskHeight: CGFloat = 162

    private let normalizedOrganization: TaskPoolOrganizationDocument
    private let childDirectoriesByParentID: [String: [TaskPoolDirectory]]
    private let tasksByDirectoryID: [String: [Task]]
    private let storedLayouts: [NodeKey: TaskPoolCanvasNodeLayout]

    init(tasks: [Task], organization: TaskPoolOrganizationDocument) {
      let normalizedOrganization = organization.normalized()
      let visibleTasks = tasks.filter { $0.status != .archived }
      let taskPlacements = Dictionary(
        uniqueKeysWithValues: normalizedOrganization.taskPlacements.map { ($0.taskID, $0.parentDirectoryID) }
      )

      self.normalizedOrganization = normalizedOrganization
      childDirectoriesByParentID = Dictionary(grouping: normalizedOrganization.directories.filter {
        $0.id != normalizedOrganization.rootDirectoryID
      }) { directory in
        directory.parentDirectoryID ?? normalizedOrganization.rootDirectoryID
      }
      tasksByDirectoryID = Dictionary(grouping: visibleTasks) { task in
        taskPlacements[task.id] ?? normalizedOrganization.inboxDirectoryID
      }
      storedLayouts = Dictionary(
        uniqueKeysWithValues: normalizedOrganization.canvasNodes.map { layout in
          (
            NodeKey(nodeID: layout.nodeID, nodeKind: layout.nodeKind),
            layout
          )
        }
      )
    }

    func build() -> BuildResult {
      let roots = rootElements().map(buildVisibleTree)

      var nodes: [Node] = []
      var edges: [Edge] = []
      var currentTop = Self.topInset

      for (index, root) in roots.enumerated() {
        let subtreeHeight = subtreeHeight(for: root)
        let centerY = currentTop + subtreeHeight / 2
        append(
          root,
          depth: 0,
          centerY: centerY,
          inheritedDirectoryOffset: .zero,
          nodes: &nodes,
          edges: &edges
        )
        currentTop += subtreeHeight
        if index < roots.count - 1 {
          currentTop += Self.rootSubtreeSpacing
        }
      }

      return BuildResult(nodes: nodes, edges: edges)
    }

    private func buildVisibleTree(_ element: TreeElement) -> VisibleNode {
      switch element {
      case .directory(let directory):
        let key = NodeKey(nodeID: directory.id, nodeKind: .directory)
        let childDirectories = childDirectories(of: directory.id)
        let childTasks = tasks(in: directory.id)
        let hasChildren = !childDirectories.isEmpty || !childTasks.isEmpty
        let isCollapsed = storedLayouts[key]?.isCollapsed ?? false
        let visibleChildren: [VisibleNode] = isCollapsed
          ? []
          : childDirectories.map { buildVisibleTree(.directory($0)) }
            + childTasks.map { buildVisibleTree(.task($0)) }

        return VisibleNode(
          key: key,
          title: displayName(for: directory),
          subtitle: directoryPathLabel(for: directory.id),
          detail: "\(childDirectories.count) 个子目录 · \(childTasks.count) 个任务",
          isCollapsed: isCollapsed,
          hasChildren: hasChildren,
          accent: directory.id == normalizedOrganization.inboxDirectoryID ? .inbox : .directory,
          task: nil,
          children: visibleChildren
        )

      case .task(let task):
        return VisibleNode(
          key: NodeKey(nodeID: task.id, nodeKind: .task),
          title: task.title,
          subtitle: directoryPathLabel(for: directoryID(for: task.id)),
          detail: task.description?.nilIfBlank,
          isCollapsed: false,
          hasChildren: false,
          accent: .task(task.status),
          task: task,
          children: []
        )
      }
    }

    private func append(
      _ node: VisibleNode,
      depth: Int,
      centerY: CGFloat,
      inheritedDirectoryOffset: CGSize,
      nodes: inout [Node],
      edges: inout [Edge]
    ) {
      let basePosition = CGPoint(
        x: Self.leadingInset + CGFloat(depth) * Self.horizontalSpacing,
        y: centerY
      )
      let ownOffset = resolvedOffset(
        for: node,
        depth: depth,
        basePosition: basePosition,
        inheritedDirectoryOffset: inheritedDirectoryOffset
      )
      let descendantOffset: CGSize
      let finalPosition: CGPoint

      switch node.key.nodeKind {
      case .directory:
        descendantOffset = inheritedDirectoryOffset + ownOffset
        finalPosition = basePosition + descendantOffset
      case .task:
        descendantOffset = inheritedDirectoryOffset
        finalPosition = basePosition + inheritedDirectoryOffset + ownOffset
      }

      nodes.append(
        Node(
          key: node.key,
          title: node.title,
          subtitle: node.subtitle,
          detail: node.detail,
          position: finalPosition,
          isCollapsed: node.isCollapsed,
          hasChildren: node.hasChildren,
          accent: node.accent,
          task: node.task
        )
      )

      guard !node.children.isEmpty else {
        return
      }

      let childHeights = node.children.map(subtreeHeight(for:))
      let totalChildrenHeight = childHeights.reduce(0, +)
        + CGFloat(max(0, node.children.count - 1)) * Self.siblingSpacing
      var currentTop = centerY - totalChildrenHeight / 2

      for (child, childHeight) in zip(node.children, childHeights) {
        let childCenterY = currentTop + childHeight / 2
        edges.append(Edge(parent: node.key, child: child.key))
        append(
          child,
          depth: depth + 1,
          centerY: childCenterY,
          inheritedDirectoryOffset: descendantOffset,
          nodes: &nodes,
          edges: &edges
        )
        currentTop += childHeight + Self.siblingSpacing
      }
    }

    private func resolvedOffset(
      for node: VisibleNode,
      depth: Int,
      basePosition: CGPoint,
      inheritedDirectoryOffset: CGSize
    ) -> CGSize {
      guard let storedLayout = storedLayouts[node.key] else {
        return .zero
      }

      let rawOffset = CGSize(
        width: storedLayout.x - basePosition.x - inheritedDirectoryOffset.width,
        height: storedLayout.y - basePosition.y - inheritedDirectoryOffset.height
      )

      switch node.key.nodeKind {
      case .directory:
        return clampedDirectoryOffset(rawOffset, depth: depth)
      case .task:
        return clampedTaskOffset(rawOffset)
      }
    }

    private func clampedDirectoryOffset(_ offset: CGSize, depth: Int) -> CGSize {
      let horizontalLimit: CGFloat = depth == 0 ? 220 : 120
      let verticalLimit: CGFloat = depth == 0 ? 240 : 140
      return CGSize(
        width: min(max(offset.width, -horizontalLimit), horizontalLimit),
        height: min(max(offset.height, -verticalLimit), verticalLimit)
      )
    }

    private func clampedTaskOffset(_ offset: CGSize) -> CGSize {
      CGSize(
        width: min(max(offset.width, -56), 56),
        height: min(max(offset.height, -48), 48)
      )
    }

    private func subtreeHeight(for node: VisibleNode) -> CGFloat {
      let selfHeight = nodeHeight(for: node)
      guard !node.children.isEmpty else {
        return selfHeight
      }

      let childrenHeight = node.children.map(subtreeHeight(for:)).reduce(0, +)
        + CGFloat(max(0, node.children.count - 1)) * Self.siblingSpacing
      return max(selfHeight, childrenHeight)
    }

    private func nodeHeight(for node: VisibleNode) -> CGFloat {
      switch node.key.nodeKind {
      case .directory:
        return node.isCollapsed ? Self.collapsedDirectoryHeight : Self.expandedDirectoryHeight
      case .task:
        return Self.taskHeight
      }
    }

    private func rootElements() -> [TreeElement] {
      childDirectories(of: normalizedOrganization.rootDirectoryID).map(TreeElement.directory)
        + tasks(in: normalizedOrganization.rootDirectoryID).map(TreeElement.task)
    }

    private func childDirectories(of directoryID: String) -> [TaskPoolDirectory] {
      (childDirectoriesByParentID[directoryID] ?? []).sorted(by: directorySortComparator)
    }

    private func tasks(in directoryID: String) -> [Task] {
      (tasksByDirectoryID[directoryID] ?? []).sorted(by: taskSortComparator)
    }

    private func directoryID(for taskID: String) -> String {
      normalizedOrganization.taskPlacement(for: taskID)?.parentDirectoryID ?? normalizedOrganization.inboxDirectoryID
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

    private var taskSortComparator: (Task, Task) -> Bool {
      { lhs, rhs in
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
  }
}

private extension CGPoint {
  static func + (lhs: CGPoint, rhs: CGSize) -> CGPoint {
    CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
  }
}

private extension CGSize {
  static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
  }
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
