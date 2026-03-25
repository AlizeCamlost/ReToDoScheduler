import Foundation
import XCTest
@testable import Norn

final class SaveTaskSequenceUseCaseTests: XCTestCase {
  func testExecuteCreatesBundledTasksInInputOrder() throws {
    let repository = InMemoryTaskRepository()
    let useCase = SaveTaskSequenceUseCase(
      repository: repository,
      dateProvider: { Date(timeIntervalSince1970: 1_700_000_500) },
      taskIDGenerator: {
        UUID().uuidString
      },
      bundleIDGenerator: {
        "bundle-1"
      }
    )

    let tasks = try useCase.execute(
      draft: TaskSequenceDraft(
        title: "今天上午",
        entries: [
          TaskSequenceEntryDraft(rawInput: "写日报 #work 20m"),
          TaskSequenceEntryDraft(rawInput: "回邮件 #ops 15m"),
          TaskSequenceEntryDraft(rawInput: "整理会议纪要 25m")
        ]
      )
    )

    XCTAssertEqual(tasks.count, 3)
    XCTAssertEqual(tasks.map(\.title), ["写日报", "回邮件", "整理会议纪要"])
    XCTAssertEqual(try repository.loadAll().map(\.title), ["写日报", "回邮件", "整理会议纪要"])

    let metadata = try XCTUnwrap(TaskBundleMetadata.metadata(for: tasks[0]))
    XCTAssertEqual(metadata.id, "bundle-1")
    XCTAssertEqual(metadata.title, "今天上午")
    XCTAssertEqual(metadata.position, 0)
    XCTAssertEqual(metadata.count, 3)

    XCTAssertEqual(TaskBundleMetadata.metadata(for: tasks[1])?.position, 1)
    XCTAssertEqual(TaskBundleMetadata.metadata(for: tasks[2])?.position, 2)
  }

  func testExecuteSkipsBlankEntries() throws {
    let repository = InMemoryTaskRepository()
    let useCase = SaveTaskSequenceUseCase(
      repository: repository,
      bundleIDGenerator: {
        "bundle-blank"
      }
    )

    let tasks = try useCase.execute(
      draft: TaskSequenceDraft(
        entries: [
          TaskSequenceEntryDraft(rawInput: ""),
          TaskSequenceEntryDraft(rawInput: "  "),
          TaskSequenceEntryDraft(rawInput: "补测试 30m")
        ]
      )
    )

    XCTAssertEqual(tasks.count, 1)
    XCTAssertEqual(tasks.first?.title, "补测试")
    XCTAssertEqual(TaskBundleMetadata.metadata(for: tasks[0])?.count, 1)
  }
}
