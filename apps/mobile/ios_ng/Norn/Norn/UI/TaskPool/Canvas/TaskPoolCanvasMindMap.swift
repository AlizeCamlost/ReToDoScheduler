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

  struct Builder {
    private static let leadingInset: CGFloat = 220
    private static let topInset: CGFloat = 170
    private static let horizontalSpacing: CGFloat = 300
    private static let verticalSpacing: CGFloat = 170
    private static let rootSubtreeSpacing: CGFloat = 36

    private let normalizedOrganization: TaskPoolOrganizationDocument
    private let childDirectoriesByParentID: [String: [TaskPoolDirectory]]
    private let tasksByDirectoryID: [String: [Task]]
    private let storedLayouts: [NodeKey: TaskPoolCanvasNodeLayout]
    private let defaultPositions: [NodeKey: CGPoint]

    init(tasks: [Task], organization: TaskPoolOrganizationDocument) {
      let normalizedOrganization = organization.normalized()
      let visibleTasks = tasks.filter { $0.status != .archived }
      let taskPlacements = Dictionary(
        uniqueKeysWithValues: normalizedOrganization.taskPlacements.map { ($0.taskID, $0.parentDirectoryID) }
      )
      let childDirectoriesByParentID = Dictionary(grouping: normalizedOrganization.directories.filter {
        $0.id != normalizedOrganization.rootDirectoryID
      }) { directory in
        directory.parentDirectoryID ?? normalizedOrganization.rootDirectoryID
      }
      let tasksByDirectoryID = Dictionary(grouping: visibleTasks) { task in
        taskPlacements[task.id] ?? normalizedOrganization.inboxDirectoryID
      }
      let storedLayouts = Dictionary(
        uniqueKeysWithValues: normalizedOrganization.canvasNodes.map { layout in
          (
            NodeKey(nodeID: layout.nodeID, nodeKind: layout.nodeKind),
            layout
          )
        }
      )

      self.normalizedOrganization = normalizedOrganization
      self.childDirectoriesByParentID = childDirectoriesByParentID
      self.tasksByDirectoryID = tasksByDirectoryID
      self.storedLayouts = storedLayouts
      self.defaultPositions = Builder.buildDefaultPositions(
        normalizedOrganization: normalizedOrganization,
        childDirectoriesByParentID: childDirectoriesByParentID,
        tasksByDirectoryID: tasksByDirectoryID,
        storedLayouts: storedLayouts,
        leadingInset: Self.leadingInset,
        topInset: Self.topInset,
        horizontalSpacing: Self.horizontalSpacing,
        verticalSpacing: Self.verticalSpacing,
        rootSubtreeSpacing: Self.rootSubtreeSpacing
      )
    }

    func build() -> BuildResult {
      var nodes: [Node] = []
      var edges: [Edge] = []

      for element in rootElements() {
        append(element, parent: nil, nodes: &nodes, edges: &edges)
      }

      return BuildResult(nodes: nodes, edges: edges)
    }

    private func append(
      _ element: TreeElement,
      parent: NodeKey?,
      nodes: inout [Node],
      edges: inout [Edge]
    ) {
      switch element {
      case .directory(let directory):
        let key = NodeKey(nodeID: directory.id, nodeKind: .directory)
        let childDirectories = childDirectories(of: directory.id)
        let childTasks = tasks(in: directory.id)
        let hasChildren = !childDirectories.isEmpty || !childTasks.isEmpty
        let isCollapsed = storedLayouts[key]?.isCollapsed ?? false

        nodes.append(
          Node(
            key: key,
            title: displayName(for: directory),
            subtitle: directoryPathLabel(for: directory.id),
            detail: "\(childDirectories.count) 个子目录 · \(childTasks.count) 个任务",
            position: resolvedPosition(for: key),
            isCollapsed: isCollapsed,
            hasChildren: hasChildren,
            accent: directory.id == normalizedOrganization.inboxDirectoryID ? .inbox : .directory,
            task: nil
          )
        )

        if let parent {
          edges.append(Edge(parent: parent, child: key))
        }

        guard !isCollapsed else {
          return
        }

        for childDirectory in childDirectories {
          append(.directory(childDirectory), parent: key, nodes: &nodes, edges: &edges)
        }
        for task in childTasks {
          append(.task(task), parent: key, nodes: &nodes, edges: &edges)
        }

      case .task(let task):
        let key = NodeKey(nodeID: task.id, nodeKind: .task)
        nodes.append(
          Node(
            key: key,
            title: task.title,
            subtitle: directoryPathLabel(for: directoryID(for: task.id)),
            detail: task.description?.nilIfBlank,
            position: resolvedPosition(for: key),
            isCollapsed: false,
            hasChildren: false,
            accent: .task(task.status),
            task: task
          )
        )

        if let parent {
          edges.append(Edge(parent: parent, child: key))
        }
      }
    }

    private func resolvedPosition(for key: NodeKey) -> CGPoint {
      if let stored = storedLayouts[key] {
        return CGPoint(x: stored.x, y: stored.y)
      }
      return defaultPositions[key] ?? CGPoint(x: Self.leadingInset, y: Self.topInset)
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

    private static func buildDefaultPositions(
      normalizedOrganization: TaskPoolOrganizationDocument,
      childDirectoriesByParentID: [String: [TaskPoolDirectory]],
      tasksByDirectoryID: [String: [Task]],
      storedLayouts: [NodeKey: TaskPoolCanvasNodeLayout],
      leadingInset: CGFloat,
      topInset: CGFloat,
      horizontalSpacing: CGFloat,
      verticalSpacing: CGFloat,
      rootSubtreeSpacing: CGFloat
    ) -> [NodeKey: CGPoint] {
      var positions: [NodeKey: CGPoint] = [:]
      var nextLeafY = topInset

      let directorySortComparator: (TaskPoolDirectory, TaskPoolDirectory) -> Bool = { lhs, rhs in
        if lhs.sortOrder != rhs.sortOrder {
          return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      let taskSortComparator: (Task, Task) -> Bool = { lhs, rhs in
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

      func childDirectories(of directoryID: String) -> [TaskPoolDirectory] {
        (childDirectoriesByParentID[directoryID] ?? []).sorted(by: directorySortComparator)
      }

      func tasks(in directoryID: String) -> [Task] {
        (tasksByDirectoryID[directoryID] ?? []).sorted(by: taskSortComparator)
      }

      func childElements(of directoryID: String) -> [TreeElement] {
        childDirectories(of: directoryID).map(TreeElement.directory)
          + tasks(in: directoryID).map(TreeElement.task)
      }

      func point(depth: Int, y: CGFloat) -> CGPoint {
        CGPoint(
          x: leadingInset + CGFloat(depth) * horizontalSpacing,
          y: y
        )
      }

      func resolvedY(for key: NodeKey, fallback: CGFloat) -> CGFloat {
        CGFloat(storedLayouts[key]?.y ?? Double(fallback))
      }

      func assign(_ element: TreeElement, depth: Int) -> CGFloat {
        switch element {
        case .directory(let directory):
          let key = NodeKey(nodeID: directory.id, nodeKind: .directory)
          let children = childElements(of: directory.id)
          let y: CGFloat
          if children.isEmpty {
            y = nextLeafY
            nextLeafY += verticalSpacing
          } else {
            let childYs = children.map { assign($0, depth: depth + 1) }
            let firstY = childYs.first ?? nextLeafY
            let lastY = childYs.last ?? firstY
            y = (firstY + lastY) / 2
          }
          let fallbackY = resolvedY(for: key, fallback: y)
          positions[key] = point(depth: depth, y: fallbackY)
          return fallbackY

        case .task(let task):
          let key = NodeKey(nodeID: task.id, nodeKind: .task)
          let y = resolvedY(for: key, fallback: nextLeafY)
          positions[key] = point(depth: depth, y: y)
          nextLeafY = max(nextLeafY, y + verticalSpacing)
          return y
        }
      }

      let rootElements = childDirectories(of: normalizedOrganization.rootDirectoryID).map(TreeElement.directory)
        + tasks(in: normalizedOrganization.rootDirectoryID).map(TreeElement.task)

      for (index, element) in rootElements.enumerated() {
        _ = assign(element, depth: 0)
        if index < rootElements.count - 1 {
          nextLeafY += rootSubtreeSpacing
        }
      }

      return positions
    }
  }
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
