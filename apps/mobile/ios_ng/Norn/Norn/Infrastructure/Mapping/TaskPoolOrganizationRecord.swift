import Foundation

struct TaskPoolOrganizationRecord: Codable, Hashable {
  struct DirectoryRecord: Codable, Hashable {
    var id: String
    var name: String
    var parentDirectoryId: String?
    var sortOrder: Int

    init(directory: TaskPoolDirectory) {
      id = directory.id
      name = directory.name
      parentDirectoryId = directory.parentDirectoryID
      sortOrder = directory.sortOrder
    }

    func toDomain() -> TaskPoolDirectory {
      TaskPoolDirectory(
        id: id,
        name: name,
        parentDirectoryID: parentDirectoryId,
        sortOrder: sortOrder
      )
    }
  }

  struct TaskPlacementRecord: Codable, Hashable {
    var taskId: String
    var parentDirectoryId: String
    var sortOrder: Int

    init(taskPlacement: TaskPoolTaskPlacement) {
      taskId = taskPlacement.taskID
      parentDirectoryId = taskPlacement.parentDirectoryID
      sortOrder = taskPlacement.sortOrder
    }

    func toDomain() -> TaskPoolTaskPlacement {
      TaskPoolTaskPlacement(
        taskID: taskId,
        parentDirectoryID: parentDirectoryId,
        sortOrder: sortOrder
      )
    }
  }

  struct CanvasNodeRecord: Codable, Hashable {
    var nodeId: String
    var nodeKind: TaskPoolCanvasNodeLayout.NodeKind
    var x: Double
    var y: Double
    var isCollapsed: Bool

    init(canvasNode: TaskPoolCanvasNodeLayout) {
      nodeId = canvasNode.nodeID
      nodeKind = canvasNode.nodeKind
      x = canvasNode.x
      y = canvasNode.y
      isCollapsed = canvasNode.isCollapsed
    }

    func toDomain() -> TaskPoolCanvasNodeLayout {
      TaskPoolCanvasNodeLayout(
        nodeID: nodeId,
        nodeKind: nodeKind,
        x: x,
        y: y,
        isCollapsed: isCollapsed
      )
    }
  }

  var version: Int
  var rootDirectoryId: String
  var inboxDirectoryId: String
  var directories: [DirectoryRecord]
  var taskPlacements: [TaskPlacementRecord]
  var canvasNodes: [CanvasNodeRecord]
  var updatedAt: String

  init(document: TaskPoolOrganizationDocument) {
    let normalized = document.normalized()
    version = normalized.version
    rootDirectoryId = normalized.rootDirectoryID
    inboxDirectoryId = normalized.inboxDirectoryID
    directories = normalized.directories.map(DirectoryRecord.init(directory:))
    taskPlacements = normalized.taskPlacements.map(TaskPlacementRecord.init(taskPlacement:))
    canvasNodes = normalized.canvasNodes.map(CanvasNodeRecord.init(canvasNode:))
    updatedAt = ISO8601DateCodec.encode(normalized.updatedAt) ?? ISO8601DateCodec.encode(Date()) ?? ""
  }

  func toDomain() -> TaskPoolOrganizationDocument {
    TaskPoolOrganizationDocument(
      version: version,
      rootDirectoryID: rootDirectoryId,
      inboxDirectoryID: inboxDirectoryId,
      directories: directories.map { $0.toDomain() },
      taskPlacements: taskPlacements.map { $0.toDomain() },
      canvasNodes: canvasNodes.map { $0.toDomain() },
      updatedAt: ISO8601DateCodec.decode(updatedAt) ?? Date()
    )
    .normalized()
  }
}
