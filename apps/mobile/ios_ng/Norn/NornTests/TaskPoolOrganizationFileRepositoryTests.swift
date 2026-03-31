import Foundation
import XCTest
@testable import Norn

final class TaskPoolOrganizationFileRepositoryTests: XCTestCase {
  func testLoadReturnsDefaultDocumentWhenFileMissing() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskPoolOrganizationFileRepository(
      baseDirectory: baseDirectory,
      dateProvider: { Date(timeIntervalSince1970: 1_700_000_000) }
    )

    let document = try repository.load()
    XCTAssertEqual(document.rootDirectoryID, TaskPoolOrganizationDocument.defaultRootDirectoryID)
    XCTAssertEqual(document.inboxDirectoryID, TaskPoolOrganizationDocument.defaultInboxDirectoryID)
    XCTAssertEqual(document.updatedAt, Date(timeIntervalSince1970: 1_700_000_000))
  }

  func testSaveAndLoadRoundTripsPlacementsAndCanvasNodes() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskPoolOrganizationFileRepository(baseDirectory: baseDirectory)
    let document = TaskPoolOrganizationDocument.defaultValue { Date(timeIntervalSince1970: 1_700_000_000) }
      .creatingDirectory(
        directoryID: "dir-1",
        name: "项目",
        parentDirectoryID: TaskPoolOrganizationDocument.defaultRootDirectoryID,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
      )
      .placingTask(
        taskID: "task-1",
        parentDirectoryID: "dir-1",
        updatedAt: Date(timeIntervalSince1970: 1_700_000_200)
      )
      .updatingCanvasNode(
        nodeID: "task-1",
        nodeKind: .task,
        x: 320,
        y: 180,
        isCollapsed: false,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_300)
      )

    try repository.save(document)
    let loaded = try repository.load()

    XCTAssertEqual(loaded.taskPlacement(for: "task-1")?.parentDirectoryID, "dir-1")
    XCTAssertEqual(loaded.canvasNodes.first?.nodeID, "task-1")
    XCTAssertEqual(loaded.canvasNodes.first?.x, 320)
  }

  private func makeTemporaryDirectory() -> URL {
    let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    return baseDirectory
  }
}
