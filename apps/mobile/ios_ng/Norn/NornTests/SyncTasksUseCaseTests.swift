import Foundation
import XCTest
@testable import Norn

final class SyncTasksUseCaseTests: XCTestCase {
  func testExecutePersistsReturnedTaskPoolOrganization() async throws {
    let taskRepository = InMemoryTaskRepository(tasks: [makeTask(id: "local-1", title: "Local")])
    let taskPoolOrganizationRepository = InMemoryTaskPoolOrganizationRepository(
      document: .defaultValue { Date(timeIntervalSince1970: 1_700_000_000) }
    )
    let remoteOrganization = TaskPoolOrganizationDocument.defaultValue { Date(timeIntervalSince1970: 1_700_000_500) }
      .creatingDirectory(
        directoryID: "dir-1",
        name: "远端目录",
        parentDirectoryID: TaskPoolOrganizationDocument.defaultRootDirectoryID,
        updatedAt: Date(timeIntervalSince1970: 1_700_000_500)
      )
    let useCase = SyncTasksUseCase(
      taskRepository: taskRepository,
      taskPoolOrganizationRepository: taskPoolOrganizationRepository,
      client: StubTaskSyncClient { tasks, organization, _ in
        XCTAssertEqual(tasks.map(\.id), ["local-1"])
        XCTAssertEqual(organization.rootDirectoryID, TaskPoolOrganizationDocument.defaultRootDirectoryID)
        return TaskSyncSnapshot(
          tasks: [makeTask(id: "remote-1", title: "Remote", updatedAt: Date(timeIntervalSince1970: 1_700_000_600))],
          taskPoolOrganization: remoteOrganization
        )
      }
    )

    let snapshot = try await useCase.execute(
      settings: SyncSettings(baseURL: "https://sync.example.com", authToken: "token", deviceID: "device-1")
    )

    XCTAssertEqual(snapshot.tasks.map(\.id), ["remote-1"])
    XCTAssertEqual(snapshot.taskPoolOrganization.directory(for: "dir-1")?.name, "远端目录")
    XCTAssertEqual(try taskPoolOrganizationRepository.load().directory(for: "dir-1")?.name, "远端目录")
  }
}
