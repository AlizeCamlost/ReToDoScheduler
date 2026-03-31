import Foundation

struct HTTPTaskSyncClient: TaskSyncClientProtocol {
  enum SyncError: LocalizedError {
    case missingBaseURL
    case missingAuthToken
    case invalidBaseURL
    case unexpectedStatusCode(Int)

    var errorDescription: String? {
      switch self {
      case .missingBaseURL:
        return "缺少 API Base URL。"
      case .missingAuthToken:
        return "缺少 API Auth Token。"
      case .invalidBaseURL:
        return "API Base URL 无效。"
      case .unexpectedStatusCode(let code):
        return "同步失败 (\(code))。"
      }
    }
  }

  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(session: URLSession = .shared) {
    self.session = session

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
    self.decoder = JSONDecoder()
  }

  func sync(
    tasks: [Task],
    taskPoolOrganization: TaskPoolOrganizationDocument,
    settings: SyncSettings
  ) async throws -> TaskSyncSnapshot {
    let baseURL = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !baseURL.isEmpty else {
      throw SyncError.missingBaseURL
    }

    let authToken = settings.authToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !authToken.isEmpty else {
      throw SyncError.missingAuthToken
    }

    let normalizedBaseURL = baseURL.replacingOccurrences(of: "/+$", with: "", options: .regularExpression)
    guard let url = URL(string: normalizedBaseURL + "/v1/tasks/sync") else {
      throw SyncError.invalidBaseURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try encoder.encode(
      TaskSyncRequest(
        deviceID: settings.deviceID,
        tasks: tasks,
        taskPoolOrganization: taskPoolOrganization
      )
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SyncError.unexpectedStatusCode(-1)
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw SyncError.unexpectedStatusCode(httpResponse.statusCode)
    }

    let payload = try decoder.decode(TaskSyncResponse.self, from: data)
    return TaskSyncSnapshot(
      tasks: payload.toTasks(),
      taskPoolOrganization: payload.toTaskPoolOrganization() ?? taskPoolOrganization
    )
  }
}
