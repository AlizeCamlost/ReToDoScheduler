import Foundation
import XCTest
@testable import Norn

final class TaskFileRepositoryTests: XCTestCase {
  func testUpsertPrefersMostRecentlyUpdatedTask() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskFileRepository(baseDirectory: baseDirectory)
    let olderTask = makeTask(
      id: "task-1",
      title: "Old",
      updatedAt: Date(timeIntervalSince1970: 100)
    )
    let newerTask = makeTask(
      id: "task-1",
      title: "New",
      updatedAt: Date(timeIntervalSince1970: 200)
    )

    try repository.save([olderTask])
    try repository.upsert([newerTask])

    let tasks = try repository.loadAll()
    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "New")
  }

  func testLoadAllOrdersByKairosRankThenUpdatedAt() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskFileRepository(baseDirectory: baseDirectory)
    let lowerRank = makeTask(
      id: "rank-1",
      title: "Rank 1",
      updatedAt: Date(timeIntervalSince1970: 100),
      extJSON: ["kairos": .object(["rank": .number(1)])]
    )
    let higherRank = makeTask(
      id: "rank-2",
      title: "Rank 2",
      updatedAt: Date(timeIntervalSince1970: 300),
      extJSON: ["kairos": .object(["rank": .number(2)])]
    )
    let noRank = makeTask(
      id: "rank-3",
      title: "No Rank",
      updatedAt: Date(timeIntervalSince1970: 400)
    )

    try repository.save([noRank, higherRank, lowerRank])

    let tasks = try repository.loadAll()
    XCTAssertEqual(tasks.map(\.id), ["rank-1", "rank-2", "rank-3"])
  }

  private func makeTemporaryDirectory() -> URL {
    let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    return baseDirectory
  }
}
