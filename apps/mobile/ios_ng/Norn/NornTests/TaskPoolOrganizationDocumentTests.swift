import Foundation
import XCTest
@testable import Norn

final class TaskPoolOrganizationDocumentTests: XCTestCase {
  func testDeletingDirectoryAdoptsDirectChildrenAndTasksIntoInbox() {
    let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)
    let document = TaskPoolOrganizationDocument(
      directories: [
        TaskPoolDirectory(id: "root", name: "根目录", sortOrder: 0),
        TaskPoolDirectory(id: "inbox", name: "待整理", parentDirectoryID: "root", sortOrder: 0),
        TaskPoolDirectory(id: "dir-parent", name: "父目录", parentDirectoryID: "root", sortOrder: 1),
        TaskPoolDirectory(id: "dir-child", name: "子目录", parentDirectoryID: "dir-parent", sortOrder: 0)
      ],
      taskPlacements: [
        TaskPoolTaskPlacement(taskID: "task-a", parentDirectoryID: "dir-parent", sortOrder: 0)
      ],
      canvasNodes: [
        TaskPoolCanvasNodeLayout(nodeID: "dir-parent", nodeKind: .directory, x: 10, y: 20),
        TaskPoolCanvasNodeLayout(nodeID: "dir-child", nodeKind: .directory, x: 30, y: 40)
      ],
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let updated = document.deletingDirectory(directoryID: "dir-parent", updatedAt: updatedAt)

    XCTAssertFalse(updated.directories.contains { $0.id == "dir-parent" })
    XCTAssertEqual(updated.directory(for: "dir-child")?.parentDirectoryID, updated.inboxDirectoryID)
    XCTAssertEqual(updated.taskPlacement(for: "task-a")?.parentDirectoryID, updated.inboxDirectoryID)
    XCTAssertFalse(updated.canvasNodes.contains { $0.nodeKind == .directory && $0.nodeID == "dir-parent" })
    XCTAssertEqual(updated.updatedAt, updatedAt)
  }

  func testPlacingTaskAndUpdatingCanvasNodeNormalizesParentDirectory() {
    let base = TaskPoolOrganizationDocument.defaultValue { Date(timeIntervalSince1970: 1_700_000_000) }
      .creatingDirectory(
        directoryID: "dir-1",
        name: "项目",
        parentDirectoryID: TaskPoolOrganizationDocument.defaultRootDirectoryID,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
      )

    let withPlacement = base.placingTask(
      taskID: "task-1",
      parentDirectoryID: "dir-1",
      updatedAt: Date(timeIntervalSince1970: 1_700_000_200)
    )
    let withCanvas = withPlacement.updatingCanvasNode(
      nodeID: "dir-1",
      nodeKind: .directory,
      x: 240,
      y: 160,
      isCollapsed: true,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_300)
    )

    XCTAssertEqual(withCanvas.taskPlacement(for: "task-1")?.parentDirectoryID, "dir-1")
    XCTAssertEqual(withCanvas.canvasNodes.first?.x, 240)
    XCTAssertEqual(withCanvas.canvasNodes.first?.isCollapsed, true)
  }
}
