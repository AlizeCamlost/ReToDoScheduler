import Foundation

struct TaskPoolOrganizationDocument: Hashable, Codable {
  static let currentVersion = 1
  static let defaultRootDirectoryID = "root"
  static let defaultRootDirectoryName = "根目录"
  static let defaultInboxDirectoryID = "inbox"
  static let defaultInboxDirectoryName = "待整理"

  var version: Int
  var rootDirectoryID: String
  var inboxDirectoryID: String
  var directories: [TaskPoolDirectory]
  var taskPlacements: [TaskPoolTaskPlacement]
  var canvasNodes: [TaskPoolCanvasNodeLayout]
  var updatedAt: Date

  init(
    version: Int = currentVersion,
    rootDirectoryID: String = defaultRootDirectoryID,
    inboxDirectoryID: String = defaultInboxDirectoryID,
    directories: [TaskPoolDirectory],
    taskPlacements: [TaskPoolTaskPlacement] = [],
    canvasNodes: [TaskPoolCanvasNodeLayout] = [],
    updatedAt: Date = Date()
  ) {
    self.version = version
    self.rootDirectoryID = rootDirectoryID
    self.inboxDirectoryID = inboxDirectoryID
    self.directories = directories
    self.taskPlacements = taskPlacements
    self.canvasNodes = canvasNodes
    self.updatedAt = updatedAt
  }

  static func defaultValue(dateProvider: () -> Date = Date.init) -> TaskPoolOrganizationDocument {
    TaskPoolOrganizationDocument(
      directories: [
        TaskPoolDirectory(
          id: defaultRootDirectoryID,
          name: defaultRootDirectoryName,
          sortOrder: 0
        ),
        TaskPoolDirectory(
          id: defaultInboxDirectoryID,
          name: defaultInboxDirectoryName,
          parentDirectoryID: defaultRootDirectoryID,
          sortOrder: 0
        )
      ],
      updatedAt: dateProvider()
    )
  }

  func normalized() -> TaskPoolOrganizationDocument {
    let fallback = TaskPoolOrganizationDocument.defaultValue { updatedAt }
    let normalizedRootDirectoryID = rootDirectoryID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      ? fallback.rootDirectoryID
      : rootDirectoryID
    let normalizedInboxDirectoryID: String = {
      let trimmed = inboxDirectoryID.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty, trimmed != normalizedRootDirectoryID else {
        return fallback.inboxDirectoryID
      }
      return trimmed
    }()

    let providedRoot = directories.first { $0.id == normalizedRootDirectoryID }
    let providedInbox = directories.first { $0.id == normalizedInboxDirectoryID }
    let uniqueOtherDirectories = uniqueDirectories.filter {
      $0.id != normalizedRootDirectoryID && $0.id != normalizedInboxDirectoryID
    }

    var normalizedDirectories: [TaskPoolDirectory] = [
      TaskPoolDirectory(
        id: normalizedRootDirectoryID,
        name: providedRoot?.name.nilIfBlank ?? Self.defaultRootDirectoryName,
        sortOrder: 0
      ),
      TaskPoolDirectory(
        id: normalizedInboxDirectoryID,
        name: providedInbox?.name.nilIfBlank ?? Self.defaultInboxDirectoryName,
        parentDirectoryID: normalizedRootDirectoryID,
        sortOrder: 0
      )
    ]
    let knownDirectoryIDs = Set([normalizedRootDirectoryID, normalizedInboxDirectoryID] + uniqueOtherDirectories.map(\.id))

    for directory in uniqueOtherDirectories {
      let normalizedParentDirectoryID: String = {
        guard
          let parentDirectoryID = directory.parentDirectoryID,
          parentDirectoryID != directory.id,
          knownDirectoryIDs.contains(parentDirectoryID)
        else {
          return normalizedRootDirectoryID
        }
        return parentDirectoryID
      }()

      normalizedDirectories.append(
        TaskPoolDirectory(
          id: directory.id,
          name: directory.name.nilIfBlank ?? "未命名目录",
          parentDirectoryID: normalizedParentDirectoryID,
          sortOrder: directory.sortOrder
        )
      )
    }

    let normalizedTaskPlacements = uniqueTaskPlacements.map { placement in
      TaskPoolTaskPlacement(
        taskID: placement.taskID,
        parentDirectoryID: knownDirectoryIDs.contains(placement.parentDirectoryID) ? placement.parentDirectoryID : normalizedInboxDirectoryID,
        sortOrder: placement.sortOrder
      )
    }

    let normalizedCanvasNodes = uniqueCanvasNodes.filter { node in
      node.nodeKind != .directory || knownDirectoryIDs.contains(node.nodeID)
    }

    return TaskPoolOrganizationDocument(
      version: max(1, version),
      rootDirectoryID: normalizedRootDirectoryID,
      inboxDirectoryID: normalizedInboxDirectoryID,
      directories: normalizedDirectories,
      taskPlacements: normalizedTaskPlacements,
      canvasNodes: normalizedCanvasNodes,
      updatedAt: updatedAt
    )
  }

  func directory(for directoryID: String) -> TaskPoolDirectory? {
    normalized().directories.first { $0.id == directoryID }
  }

  func taskPlacement(for taskID: String) -> TaskPoolTaskPlacement? {
    normalized().taskPlacements.first { $0.taskID == taskID }
  }

  func creatingDirectory(
    directoryID: String,
    name: String,
    parentDirectoryID: String?,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return normalized() }

    var next = normalized()
    guard next.directory(for: directoryID) == nil else { return next }

    let normalizedParentDirectoryID = next.normalizedParentDirectoryID(parentDirectoryID, excluding: directoryID)
    next.directories.append(
      TaskPoolDirectory(
        id: directoryID,
        name: trimmedName,
        parentDirectoryID: normalizedParentDirectoryID,
        sortOrder: next.nextDirectorySortOrder(in: normalizedParentDirectoryID)
      )
    )
    next.updatedAt = updatedAt
    return next.normalized()
  }

  func renamingDirectory(
    directoryID: String,
    name: String,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return normalized() }

    var next = normalized()
    guard let index = next.directories.firstIndex(where: { $0.id == directoryID }) else {
      return next
    }

    next.directories[index].name = trimmedName
    next.updatedAt = updatedAt
    return next.normalized()
  }

  func deletingDirectory(
    directoryID: String,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    var next = normalized()
    guard
      directoryID != next.rootDirectoryID,
      directoryID != next.inboxDirectoryID,
      next.directory(for: directoryID) != nil
    else {
      return next
    }

    var nextInboxDirectorySortOrder = next.nextDirectorySortOrder(in: next.inboxDirectoryID)
    next.directories = next.directories.compactMap { directory in
      guard directory.id != directoryID else { return nil }
      guard directory.parentDirectoryID == directoryID else { return directory }

      defer {
        nextInboxDirectorySortOrder += 1
      }
      return TaskPoolDirectory(
        id: directory.id,
        name: directory.name,
        parentDirectoryID: next.inboxDirectoryID,
        sortOrder: nextInboxDirectorySortOrder
      )
    }

    var nextInboxTaskSortOrder = next.nextTaskSortOrder(in: next.inboxDirectoryID)
    next.taskPlacements = next.taskPlacements.map { placement in
      guard placement.parentDirectoryID == directoryID else { return placement }
      defer {
        nextInboxTaskSortOrder += 1
      }
      return TaskPoolTaskPlacement(
        taskID: placement.taskID,
        parentDirectoryID: next.inboxDirectoryID,
        sortOrder: nextInboxTaskSortOrder
      )
    }

    next.canvasNodes.removeAll {
      $0.nodeKind == .directory && $0.nodeID == directoryID
    }
    next.updatedAt = updatedAt
    return next.normalized()
  }

  func movingDirectory(
    directoryID: String,
    parentDirectoryID: String?,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    var next = normalized()
    guard
      directoryID != next.rootDirectoryID,
      directoryID != next.inboxDirectoryID,
      let index = next.directories.firstIndex(where: { $0.id == directoryID })
    else {
      return next
    }

    let descendants = next.descendantDirectoryIDs(of: directoryID)
    let normalizedParentDirectoryID: String = {
      guard let candidate = next.normalizedParentDirectoryID(parentDirectoryID, excluding: directoryID) else {
        return next.rootDirectoryID
      }
      return descendants.contains(candidate) ? next.rootDirectoryID : candidate
    }()

    next.directories[index].parentDirectoryID = normalizedParentDirectoryID
    next.directories[index].sortOrder = next.nextDirectorySortOrder(
      in: normalizedParentDirectoryID,
      excluding: directoryID
    )
    next.updatedAt = updatedAt
    return next.normalized()
  }

  func placingTask(
    taskID: String,
    parentDirectoryID: String?,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    var next = normalized()
    let normalizedParentDirectoryID = next.normalizedParentDirectoryID(parentDirectoryID, excluding: nil) ?? next.inboxDirectoryID

    if let index = next.taskPlacements.firstIndex(where: { $0.taskID == taskID }) {
      next.taskPlacements[index].parentDirectoryID = normalizedParentDirectoryID
      next.taskPlacements[index].sortOrder = next.nextTaskSortOrder(in: normalizedParentDirectoryID, excluding: taskID)
    } else {
      next.taskPlacements.append(
        TaskPoolTaskPlacement(
          taskID: taskID,
          parentDirectoryID: normalizedParentDirectoryID,
          sortOrder: next.nextTaskSortOrder(in: normalizedParentDirectoryID)
        )
      )
    }

    next.updatedAt = updatedAt
    return next.normalized()
  }

  func updatingCanvasNode(
    nodeID: String,
    nodeKind: TaskPoolCanvasNodeLayout.NodeKind,
    x: Double,
    y: Double,
    isCollapsed: Bool,
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    var next = normalized()
    if nodeKind == .directory, next.directory(for: nodeID) == nil {
      return next
    }

    let replacement = TaskPoolCanvasNodeLayout(
      nodeID: nodeID,
      nodeKind: nodeKind,
      x: x,
      y: y,
      isCollapsed: isCollapsed
    )
    if let index = next.canvasNodes.firstIndex(where: { $0.nodeID == nodeID && $0.nodeKind == nodeKind }) {
      next.canvasNodes[index] = replacement
    } else {
      next.canvasNodes.append(replacement)
    }
    next.updatedAt = updatedAt
    return next.normalized()
  }

  func resettingCanvasPositions(
    autoLayoutPositions: [String: CGPoint],
    updatedAt: Date
  ) -> TaskPoolOrganizationDocument {
    var next = normalized()
    for index in next.canvasNodes.indices {
      let node = next.canvasNodes[index]
      let stableID = "\(node.nodeKind.rawValue):\(node.nodeID)"
      if let position = autoLayoutPositions[stableID] {
        next.canvasNodes[index].x = position.x
        next.canvasNodes[index].y = position.y
      }
    }
    next.updatedAt = updatedAt
    return next
  }

  private var uniqueDirectories: [TaskPoolDirectory] {
    var seen = Set<String>()
    return directories.filter { directory in
      seen.insert(directory.id).inserted
    }
  }

  private var uniqueTaskPlacements: [TaskPoolTaskPlacement] {
    var seen = Set<String>()
    return taskPlacements.filter { placement in
      seen.insert(placement.taskID).inserted
    }
  }

  private var uniqueCanvasNodes: [TaskPoolCanvasNodeLayout] {
    var seen = Set<String>()
    return canvasNodes.filter { node in
      seen.insert("\(node.nodeKind.rawValue):\(node.nodeID)").inserted
    }
  }

  private func descendantDirectoryIDs(of directoryID: String) -> Set<String> {
    let childIDs = directories
      .filter { $0.parentDirectoryID == directoryID }
      .map(\.id)
    guard !childIDs.isEmpty else {
      return []
    }

    var descendants = Set(childIDs)
    for childID in childIDs {
      descendants.formUnion(descendantDirectoryIDs(of: childID))
    }
    return descendants
  }

  private func normalizedParentDirectoryID(
    _ parentDirectoryID: String?,
    excluding directoryID: String?
  ) -> String? {
    guard let parentDirectoryID else {
      return rootDirectoryID
    }

    guard
      parentDirectoryID != directoryID,
      directories.contains(where: { $0.id == parentDirectoryID })
    else {
      return rootDirectoryID
    }
    return parentDirectoryID
  }

  private func nextDirectorySortOrder(
    in parentDirectoryID: String?,
    excluding directoryID: String? = nil
  ) -> Int {
    let siblingSortOrders = directories
      .filter { $0.parentDirectoryID == parentDirectoryID && $0.id != directoryID }
      .map(\.sortOrder)
    return (siblingSortOrders.max() ?? -1) + 1
  }

  private func nextTaskSortOrder(
    in parentDirectoryID: String,
    excluding taskID: String? = nil
  ) -> Int {
    let siblingSortOrders = taskPlacements
      .filter { $0.parentDirectoryID == parentDirectoryID && $0.taskID != taskID }
      .map(\.sortOrder)
    return (siblingSortOrders.max() ?? -1) + 1
  }
}

private extension String {
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
