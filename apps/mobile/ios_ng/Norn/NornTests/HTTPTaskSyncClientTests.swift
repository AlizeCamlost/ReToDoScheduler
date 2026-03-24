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

    let syncedTasks = try await client.sync(tasks: [task], settings: settings)
    XCTAssertEqual(syncedTasks.map(\.id), ["remote-1"])
    XCTAssertEqual(syncedTasks.first?.tags, ["sync"])
    XCTAssertEqual(syncedTasks.first?.steps.first?.progress?.completedAt, responseTime)
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
