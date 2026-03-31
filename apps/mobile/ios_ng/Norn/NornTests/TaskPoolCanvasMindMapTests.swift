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

  func testAutoLayoutCentersParentBetweenSiblingLeaves() throws {
    let graph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha"),
        makeTask(id: "task-c", title: "Charlie")
      ],
      organization: organizationWithSiblingLeaves()
    )

    let parent = try unwrapNode(directoryKey("dir-a"), in: graph)
    let firstChild = try unwrapNode(taskKey("task-a"), in: graph)
    let secondChild = try unwrapNode(taskKey("task-c"), in: graph)

    XCTAssertTrue(firstChild.position.x > parent.position.x)
    XCTAssertTrue(secondChild.position.x > parent.position.x)
    XCTAssertEqual(parent.position.y, (firstChild.position.y + secondChild.position.y) / 2, accuracy: 0.001)
    XCTAssertTrue(firstChild.position.y < secondChild.position.y)
  }

  func testStoredDirectoryPositionOffsetsWholeVisibleSubtree() throws {
    let baseGraph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha"),
        makeTask(id: "task-b", title: "Beta")
      ],
      organization: organization()
    )
    let movedGraph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha"),
        makeTask(id: "task-b", title: "Beta")
      ],
      organization: organization(
        canvasNodes: [
          TaskPoolCanvasNodeLayout(nodeID: "dir-a", nodeKind: .directory, x: 420, y: 420)
        ]
      )
    )

    let baseParent = try unwrapNode(directoryKey("dir-a"), in: baseGraph)
    let movedParent = try unwrapNode(directoryKey("dir-a"), in: movedGraph)
    let baseChildDirectory = try unwrapNode(directoryKey("dir-b"), in: baseGraph)
    let movedChildDirectory = try unwrapNode(directoryKey("dir-b"), in: movedGraph)
    let baseChildTask = try unwrapNode(taskKey("task-a"), in: baseGraph)
    let movedChildTask = try unwrapNode(taskKey("task-a"), in: movedGraph)

    let dx = movedParent.position.x - baseParent.position.x
    let dy = movedParent.position.y - baseParent.position.y

    XCTAssertEqual(movedChildDirectory.position.x - baseChildDirectory.position.x, dx, accuracy: 0.001)
    XCTAssertEqual(movedChildDirectory.position.y - baseChildDirectory.position.y, dy, accuracy: 0.001)
    XCTAssertEqual(movedChildTask.position.x - baseChildTask.position.x, dx, accuracy: 0.001)
    XCTAssertEqual(movedChildTask.position.y - baseChildTask.position.y, dy, accuracy: 0.001)
  }

  func testStoredTaskPositionAppliesOffsetWithoutClamping() throws {
    let baseGraph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha")
      ],
      organization: organizationWithSiblingLeaves()
    )
    let movedGraph = TaskPoolCanvasMindMap(
      tasks: [
        makeTask(id: "task-a", title: "Alpha")
      ],
      organization: organizationWithSiblingLeaves(
        canvasNodes: [
          TaskPoolCanvasNodeLayout(nodeID: "task-a", nodeKind: .task, x: 2_000, y: 2_000)
        ]
      )
    )

    let baseTask = try unwrapNode(taskKey("task-a"), in: baseGraph)
    let movedTask = try unwrapNode(taskKey("task-a"), in: movedGraph)

    XCTAssertEqual(movedTask.position.x, 2_000, accuracy: 0.001)
    XCTAssertEqual(movedTask.position.y, 2_000, accuracy: 0.001)
    XCTAssertTrue(movedTask.position.x - baseTask.position.x > 56)
    XCTAssertTrue(movedTask.position.y - baseTask.position.y > 48)
  }

  func testAutoLayoutPositionsIgnoresStoredOffsets() throws {
    let org = organizationWithSiblingLeaves(
      canvasNodes: [
        TaskPoolCanvasNodeLayout(nodeID: "task-a", nodeKind: .task, x: 2_000, y: 2_000)
      ]
    )
    let graph = TaskPoolCanvasMindMap(
      tasks: [makeTask(id: "task-a", title: "Alpha")],
      organization: org
    )
    let autoPositions = TaskPoolCanvasMindMap.autoLayoutPositions(
      tasks: [makeTask(id: "task-a", title: "Alpha")],
      organization: org
    )

    let autoPositionedTask = try XCTUnwrap(autoPositions[taskKey("task-a")])
    let storedOffsetTask = try unwrapNode(taskKey("task-a"), in: graph)

    XCTAssertTrue(abs(autoPositionedTask.x - storedOffsetTask.position.x) > 1)
    XCTAssertTrue(autoPositionedTask.x < 600)
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

  private func organizationWithSiblingLeaves(
    canvasNodes: [TaskPoolCanvasNodeLayout] = []
  ) -> TaskPoolOrganizationDocument {
    TaskPoolOrganizationDocument(
      directories: [
        TaskPoolDirectory(id: "root", name: "根目录", sortOrder: 0),
        TaskPoolDirectory(id: "inbox", name: "待整理", parentDirectoryID: "root", sortOrder: 0),
        TaskPoolDirectory(id: "dir-a", name: "项目", parentDirectoryID: "root", sortOrder: 1)
      ],
      taskPlacements: [
        TaskPoolTaskPlacement(taskID: "task-a", parentDirectoryID: "dir-a", sortOrder: 0),
        TaskPoolTaskPlacement(taskID: "task-c", parentDirectoryID: "dir-a", sortOrder: 1)
      ],
      canvasNodes: canvasNodes,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
  }

  private func unwrapNode(
    _ key: TaskPoolCanvasMindMap.NodeKey,
    in graph: TaskPoolCanvasMindMap,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> TaskPoolCanvasMindMap.Node {
    guard let node = graph.nodes.first(where: { $0.key == key }) else {
      XCTFail("Missing node \(key.stableID)", file: file, line: line)
      throw TestFailure()
    }
    return node
  }

  private func directoryKey(_ id: String) -> TaskPoolCanvasMindMap.NodeKey {
    TaskPoolCanvasMindMap.NodeKey(nodeID: id, nodeKind: .directory)
  }

  private func taskKey(_ id: String) -> TaskPoolCanvasMindMap.NodeKey {
    TaskPoolCanvasMindMap.NodeKey(nodeID: id, nodeKind: .task)
  }
}

private struct TestFailure: Error {}
