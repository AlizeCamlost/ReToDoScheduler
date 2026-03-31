import Foundation
import XCTest
@testable import Norn

final class TaskPoolCanvasMindMapTests: XCTestCase {
  func testExpandedDirectoryBuildsVisibleSubtreeAndEdges() {
    let graph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha", dueAt: Date(timeIntervalSince1970: 1_700_000_300)),
        makeTask(id: "task-b", title: "Beta", dueAt: Date(timeIntervalSince1970: 1_700_000_600))
      ],
      organization: organization()
    )

    XCTAssertTrue(graph.nodes.contains(where: { $0.key == directoryKey("dir-a") }))
    XCTAssertTrue(graph.nodes.contains(where: { $0.key == directoryKey("dir-b") }))
    XCTAssertTrue(graph.nodes.contains(where: { $0.key == taskKey("task-a") }))
    XCTAssertTrue(graph.nodes.contains(where: { $0.key == taskKey("task-b") }))
    XCTAssertTrue(graph.edges.contains(where: { $0.parent == directoryKey("dir-a") && $0.child == directoryKey("dir-b") }))
    XCTAssertTrue(graph.edges.contains(where: { $0.parent == directoryKey("dir-a") && $0.child == taskKey("task-a") }))
    XCTAssertTrue(graph.edges.contains(where: { $0.parent == directoryKey("dir-b") && $0.child == taskKey("task-b") }))
  }

  func testCollapsedDirectoryHidesDescendantsAndTheirEdges() {
    let graph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha"),
        makeTask(id: "task-b", title: "Beta")
      ],
      organization: organization(
        canvasNodes: [
          TaskPoolCanvasNodeLayout(nodeID: "dir-a", nodeKind: .directory, x: 260, y: 220, isCollapsed: true)
        ]
      )
    )

    XCTAssertTrue(graph.nodes.contains(where: { $0.key == directoryKey("dir-a") }))
    XCTAssertFalse(graph.nodes.contains(where: { $0.key == directoryKey("dir-b") }))
    XCTAssertFalse(graph.nodes.contains(where: { $0.key == taskKey("task-a") }))
    XCTAssertFalse(graph.nodes.contains(where: { $0.key == taskKey("task-b") }))
    XCTAssertFalse(graph.edges.contains(where: { $0.parent == directoryKey("dir-a") }))
    XCTAssertEqual(graph.nodes.first(where: { $0.key == directoryKey("dir-a") })?.isCollapsed, true)
  }

  func testStoredPositionsOverrideDefaultTreeLayout() {
    let graph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha")
      ],
      organization: organization(
        canvasNodes: [
          TaskPoolCanvasNodeLayout(nodeID: "dir-a", nodeKind: .directory, x: 840, y: 410),
          TaskPoolCanvasNodeLayout(nodeID: "task-a", nodeKind: .task, x: 1_120, y: 470)
        ]
      )
    )

    XCTAssertEqual(graph.nodes.first(where: { $0.key == directoryKey("dir-a") })?.position, CGPoint(x: 840, y: 410))
    XCTAssertEqual(graph.nodes.first(where: { $0.key == taskKey("task-a") })?.position, CGPoint(x: 1_120, y: 470))
  }

  private func organization(canvasNodes: [TaskPoolCanvasNodeLayout] = []) -> TaskPoolOrganizationDocument {
    TaskPoolOrganizationDocument(
      directories: [
        TaskPoolDirectory(id: "root", name: "根目录", sortOrder: 0),
        TaskPoolDirectory(id: "inbox", name: "待整理", parentDirectoryID: "root", sortOrder: 0),
        TaskPoolDirectory(id: "dir-a", name: "项目", parentDirectoryID: "root", sortOrder: 1),
        TaskPoolDirectory(id: "dir-b", name: "子目录", parentDirectoryID: "dir-a", sortOrder: 0)
      ],
      taskPlacements: [
        TaskPoolTaskPlacement(taskID: "task-a", parentDirectoryID: "dir-a", sortOrder: 0),
        TaskPoolTaskPlacement(taskID: "task-b", parentDirectoryID: "dir-b", sortOrder: 0)
      ],
      canvasNodes: canvasNodes,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
  }

  private func directoryKey(_ id: String) -> TaskPoolCanvasMindMap.NodeKey {
    TaskPoolCanvasMindMap.NodeKey(nodeID: id, nodeKind: .directory)
  }

  private func taskKey(_ id: String) -> TaskPoolCanvasMindMap.NodeKey {
    TaskPoolCanvasMindMap.NodeKey(nodeID: id, nodeKind: .task)
  }
}
