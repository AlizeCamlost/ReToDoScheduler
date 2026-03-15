import Foundation

struct SyncResult: Decodable {
  var synced: Int?
  var items: [Task]
}

private struct SyncRequest: Encodable {
  var deviceId: String
  var tasks: [Task]
}

enum SyncServiceError: LocalizedError {
  case missingBaseURL
  case missingAuthToken
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .missingBaseURL:
      return "缺少 API 地址，请先在设置中填写。"
    case .missingAuthToken:
      return "缺少 API 令牌，请先在设置中填写。"
    case .invalidResponse:
      return "服务端返回了无效响应。"
    }
  }
}

struct SyncService {
  private let repository: TaskRepository
  private let session: URLSession

  init(repository: TaskRepository = .shared, session: URLSession = .shared) {
    self.repository = repository
    self.session = session
  }

  func syncTasks() async throws -> Int {
    let baseURL = await repository.value(for: .apiBaseURL).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !baseURL.isEmpty else {
      throw SyncServiceError.missingBaseURL
    }

    let token = await repository.value(for: .apiAuthToken).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      throw SyncServiceError.missingAuthToken
    }

    let deviceID = await repository.getOrCreateDeviceID()
    let localTasks = await repository.listTasks()

    guard let url = URL(string: baseURL.replacingOccurrences(of: "/+$", with: "", options: .regularExpression) + "/v1/tasks/sync") else {
      throw SyncServiceError.missingBaseURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 20

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    request.httpBody = try encoder.encode(
      SyncRequest(
        deviceId: deviceID,
        tasks: localTasks
      )
    )

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
      throw SyncServiceError.invalidResponse
    }

    let decoder = JSONDecoder()
    let payload = try decoder.decode(SyncResult.self, from: data)
    try await repository.upsert(payload.items)
    return payload.synced ?? localTasks.count
  }
}
