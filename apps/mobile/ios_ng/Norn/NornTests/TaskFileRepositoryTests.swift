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

  func testLoadAllOrdersBySequenceRankBeforeKairosRank() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskFileRepository(baseDirectory: baseDirectory)
    let manuallyOrdered = makeTask(
      id: "sequence-1",
      title: "Sequence 1",
      updatedAt: Date(timeIntervalSince1970: 100),
      extJSON: ["norn": .object(["sequenceRank": .number(0)])]
    )
    let kairosFirst = makeTask(
      id: "sequence-2",
      title: "Kairos 1",
      updatedAt: Date(timeIntervalSince1970: 400),
      extJSON: ["kairos": .object(["rank": .number(1)])]
    )
    let manuallySecond = makeTask(
      id: "sequence-3",
      title: "Sequence 2",
      updatedAt: Date(timeIntervalSince1970: 200),
      extJSON: ["norn": .object(["sequenceRank": .number(1)])]
    )

    try repository.save([kairosFirst, manuallySecond, manuallyOrdered])

    let tasks = try repository.loadAll()
    XCTAssertEqual(tasks.map(\.id), ["sequence-1", "sequence-3", "sequence-2"])
  }

  func testSaveAndLoadRoundTripsStepProgress() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskFileRepository(baseDirectory: baseDirectory)
    let startedAt = Date(timeIntervalSince1970: 120)
    let completedAt = Date(timeIntervalSince1970: 180)
    let task = makeTask(
      id: "task-1",
      title: "Task",
      steps: [
        TaskStep(
          id: "s1",
          title: "第一步",
          estimatedMinutes: 15,
          minChunkMinutes: 10,
          progress: TaskStepProgress(startedAt: startedAt, completedAt: completedAt)
        )
      ]
    )

    try repository.save([task])
    let tasks = try repository.loadAll()

    XCTAssertEqual(tasks.first?.steps.first?.progress?.startedAt, startedAt)
    XCTAssertEqual(tasks.first?.steps.first?.progress?.completedAt, completedAt)
  }

  func testToggleCompletionSyncsTaskAndStepProgress() throws {
    let baseDirectory = makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let repository = TaskFileRepository(baseDirectory: baseDirectory)
    let task = makeTask(
      id: "task-1",
      title: "Task",
      steps: [
        TaskStep(id: "s1", title: "第一步", estimatedMinutes: 15, minChunkMinutes: 10),
        TaskStep(id: "s2", title: "第二步", estimatedMinutes: 20, minChunkMinutes: 10, dependsOnStepIDs: ["s1"])
      ]
    )

    try repository.save([task])
    try repository.toggleCompletion(taskID: "task-1")

    var tasks = try repository.loadAll()
    XCTAssertEqual(tasks.first?.status, .done)
    XCTAssertTrue(tasks.first?.allStepsCompleted ?? false)

    try repository.toggleCompletion(taskID: "task-1")
    tasks = try repository.loadAll()
    XCTAssertEqual(tasks.first?.status, .todo)
    XCTAssertEqual(tasks.first?.completedStepCount, 0)
  }

  private func makeTemporaryDirectory() -> URL {
    let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    return baseDirectory
  }
}
