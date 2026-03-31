import Foundation
import XCTest
@testable import Norn

final class HTTPTaskSyncClientTests: XCTestCase {
  override func tearDown() {
    URLProtocolStub.handler = nil
    super.tearDown()
  }

  func testSyncBuildsRequestAndDecodesResponse() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    let session = URLSession(configuration: configuration)
    let client = HTTPTaskSyncClient(session: session)
    let startedAt = Date(timeIntervalSince1970: 450)
    let completedAt = Date(timeIntervalSince1970: 500)
    let responseTime = Date(timeIntervalSince1970: 1_700_000_100)
    let responseTimeText = ISO8601DateCodec.encode(responseTime) ?? ""
    let task = makeTask(
      id: "local-1",
      title: "Local Task",
      steps: [
        TaskStep(
          id: "s1",
          title: "第一步",
          estimatedMinutes: 15,
          minChunkMinutes: 10,
          progress: TaskStepProgress(startedAt: startedAt, completedAt: completedAt)
        )
      ],
      updatedAt: Date(timeIntervalSince1970: 500)
    )
    let settings = SyncSettings(
      baseURL: "https://sync.example.com/",
      authToken: "secret-token",
      deviceID: "device-1"
    )

    URLProtocolStub.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.absoluteString, "https://sync.example.com/v1/tasks/sync")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")

      let body = try XCTUnwrap(request.httpBody)
      let payload = try JSONDecoder().decode(CapturedSyncRequest.self, from: body)
      XCTAssertEqual(payload.deviceId, "device-1")
      XCTAssertEqual(payload.tasks.map(\.id), ["local-1"])
      XCTAssertEqual(payload.tasks.first?.steps.first?.progress?.completedAt, ISO8601DateCodec.encode(completedAt))
      XCTAssertEqual(payload.taskPoolOrganization?.inboxDirectoryId, TaskPoolOrganizationDocument.defaultInboxDirectoryID)

      let url = try XCTUnwrap(request.url)
      let response = try XCTUnwrap(HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      ))
      let data = """
      {
        "deviceId": "device-1",
        "synced": 1,
        "taskPoolOrganization": {
          "version": 1,
          "rootDirectoryId": "root",
          "inboxDirectoryId": "inbox",
          "directories": [
            { "id": "root", "name": "根目录", "sortOrder": 0 },
            { "id": "inbox", "name": "待整理", "parentDirectoryId": "root", "sortOrder": 0 },
            { "id": "dir-1", "name": "项目", "parentDirectoryId": "root", "sortOrder": 1 }
          ],
          "taskPlacements": [
            { "taskId": "remote-1", "parentDirectoryId": "dir-1", "sortOrder": 0 }
          ],
          "canvasNodes": [
            { "nodeId": "dir-1", "nodeKind": "directory", "x": 120, "y": 80, "isCollapsed": false }
          ],
          "updatedAt": "\(responseTimeText)"
        },
        "items": [
          {
            "id": "remote-1",
            "title": "Remote Task",
            "rawInput": "Remote Task",
            "description": null,
            "status": "todo",
            "estimatedMinutes": 30,
            "minChunkMinutes": 25,
            "dueAt": null,
            "tags": ["sync"],
            "scheduleValue": { "rewardOnTime": 10, "penaltyMissed": 25 },
            "dependsOnTaskIds": [],
            "steps": [
              {
                "id": "remote-step-1",
                "title": "远端步骤",
                "estimatedMinutes": 20,
                "minChunkMinutes": 10,
                "dependsOnStepIds": [],
                "progress": {
                  "startedAt": "\(responseTimeText)",
                  "completedAt": "\(responseTimeText)"
                }
              }
            ],
            "concurrencyMode": "serial",
            "createdAt": "\(responseTimeText)",
            "updatedAt": "\(responseTimeText)",
            "extJson": {}
          }
        ]
      }
      """.data(using: .utf8) ?? Data()
      return (response, data)
    }

    let snapshot = try await client.sync(
      tasks: [task],
      taskPoolOrganization: .defaultValue { Date(timeIntervalSince1970: 1_700_000_050) },
      settings: settings
    )
    XCTAssertEqual(snapshot.tasks.map(\.id), ["remote-1"])
    XCTAssertEqual(snapshot.tasks.first?.tags, ["sync"])
    XCTAssertEqual(snapshot.tasks.first?.steps.first?.progress?.completedAt, responseTime)
    XCTAssertEqual(snapshot.taskPoolOrganization.taskPlacements.first?.parentDirectoryID, "dir-1")
  }
}

private struct CapturedSyncRequest: Decodable {
  struct CapturedStep: Decodable {
    struct CapturedProgress: Decodable {
      var startedAt: String?
      var completedAt: String?
    }

    var id: String
    var progress: CapturedProgress?
  }

  struct CapturedTask: Decodable {
    var id: String
    var steps: [CapturedStep]
  }

  var deviceId: String
  var tasks: [CapturedTask]
  var taskPoolOrganization: CapturedTaskPoolOrganization?
}

private struct CapturedTaskPoolOrganization: Decodable {
  var inboxDirectoryId: String
}

private final class URLProtocolStub: URLProtocol {
  static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
