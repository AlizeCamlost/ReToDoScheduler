import Foundation

struct SyncSettings: Hashable {
  var baseURL: String
  var authToken: String
  var deviceID: String

  static let empty = SyncSettings(baseURL: "", authToken: "", deviceID: "")

  var isConfigured: Bool {
    !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
